"""Content moderation service for filtering inappropriate content."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from src.core.logging import get_logger
from src.schemas.moderation import (
    ModerationAction,
    ModerationCategory,
    ModerationEvent,
    ModerationResult,
)

logger = get_logger(__name__)

# Keywords/patterns that trigger moderation (basic filter)
_BLOCKED_PATTERNS: list[tuple[str, ModerationCategory]] = [
    # Hate speech patterns (simplified examples)
    ("kill all", ModerationCategory.HATE_SPEECH),
    ("genocide", ModerationCategory.HATE_SPEECH),
    # Self-harm triggers
    ("how to hurt myself", ModerationCategory.SELF_HARM),
    ("suicide method", ModerationCategory.SELF_HARM),
]

_FLAGGED_PATTERNS: list[tuple[str, ModerationCategory]] = []


class ModerationService:
    """Service for content moderation.

    Uses Anthropic's built-in safety features as the primary layer.
    Provides a custom secondary filter for game-specific content rules.
    """

    def __init__(self, session_id: uuid.UUID | None = None) -> None:
        self.session_id = session_id
        self._events: list[ModerationEvent] = []

    async def check_player_message(
        self,
        content: str,
        user_id: uuid.UUID | None = None,
        room_id: uuid.UUID | None = None,
    ) -> ModerationResult:
        """Check a player message for inappropriate content.

        Args:
            content: The message text to check
            user_id: ID of the user sending the message
            room_id: ID of the room

        Returns:
            ModerationResult with action and categories
        """
        return await self._check_content(
            content=content,
            content_type="player_message",
            user_id=user_id,
            room_id=room_id,
        )

    async def check_scenario_content(
        self,
        content: str,
        user_id: uuid.UUID | None = None,
    ) -> ModerationResult:
        """Check scenario content for inappropriate content.

        Args:
            content: The scenario text to check
            user_id: ID of the user creating the scenario

        Returns:
            ModerationResult with action and categories
        """
        return await self._check_content(
            content=content,
            content_type="scenario",
            user_id=user_id,
        )

    async def _check_content(
        self,
        content: str,
        content_type: str,
        user_id: uuid.UUID | None = None,
        room_id: uuid.UUID | None = None,
    ) -> ModerationResult:
        """Internal content check logic.

        First applies basic pattern matching, then relies on
        Anthropic's built-in safety features for AI-generated content.

        Args:
            content: Text to check
            content_type: Type of content being checked
            user_id: Optional user ID for logging
            room_id: Optional room ID for logging

        Returns:
            ModerationResult
        """
        content_lower = content.lower()
        triggered_categories: list[ModerationCategory] = []
        action = ModerationAction.ALLOWED

        # Check blocked patterns
        for pattern, category in _BLOCKED_PATTERNS:
            if pattern in content_lower:
                triggered_categories.append(category)
                action = ModerationAction.BLOCKED

        # Check flagged patterns
        if action == ModerationAction.ALLOWED:
            for pattern, category in _FLAGGED_PATTERNS:
                if pattern in content_lower:
                    triggered_categories.append(category)
                    action = ModerationAction.FLAGGED

        result = ModerationResult(
            allowed=action in (ModerationAction.ALLOWED, ModerationAction.FLAGGED),
            action=action,
            categories=list(set(triggered_categories)),
            reason=f"Content flagged for: {', '.join(c.value for c in triggered_categories)}"
            if triggered_categories
            else None,
        )

        # Log moderation event if triggered
        if action != ModerationAction.ALLOWED:
            event = ModerationEvent(
                event_id=uuid.uuid4(),
                session_id=self.session_id,
                user_id=user_id,
                room_id=room_id,
                content_type=content_type,
                action=action,
                categories=result.categories,
                original_content_preview=content[:200],
                timestamp=datetime.now(UTC),
            )
            self._events.append(event)
            await self._log_event(event)

        return result

    async def _log_event(self, event: ModerationEvent) -> None:
        """Log a moderation event."""
        logger.warning(
            "Moderation event: action=%s, categories=%s, content_type=%s, user_id=%s",
            event.action.value,
            [c.value for c in event.categories],
            event.content_type,
            str(event.user_id),
        )

    def get_events(self) -> list[ModerationEvent]:
        """Return all moderation events logged in this session."""
        return list(self._events)

    @staticmethod
    def build_safety_system_prompt_addition() -> str:
        """Return additional system prompt text for content safety.

        This is appended to AI prompts to enforce content guidelines.
        """
        return (
            "\n\nCONTENT SAFETY RULES:\n"
            "- Do not generate content that promotes real-world violence, self-harm, or hatred.\n"
            "- Keep content appropriate for a fantasy RPG context.\n"
            "- If a player attempts to use the game to explore genuinely harmful scenarios, "
            "redirect the narrative without engaging with the harmful content.\n"
        )

    @staticmethod
    def extract_moderation_metadata(
        anthropic_response: Any,
    ) -> dict[str, Any]:
        """Extract moderation-related metadata from Anthropic response.

        Args:
            anthropic_response: Raw response from Anthropic API

        Returns:
            Dictionary with moderation metadata
        """
        metadata: dict[str, Any] = {}

        # Anthropic responses may include stop_reason indicating safety
        if hasattr(anthropic_response, "stop_reason"):
            metadata["stop_reason"] = anthropic_response.stop_reason

        return metadata
