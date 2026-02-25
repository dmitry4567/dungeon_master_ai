"""State extractor for extracting world state changes from DM responses."""
import json
import re
from dataclasses import dataclass
from typing import Any

import httpx

from src.core.config import get_settings
from src.core.logging import get_logger

logger = get_logger(__name__)


def _extract_json(text: str) -> str:
    """Extract JSON from text, handling markdown code blocks."""
    pattern = r"```(?:json)?\s*([\s\S]*?)```"
    match = re.search(pattern, text)
    if match:
        return match.group(1).strip()
    return text.strip()


@dataclass
class StateUpdate:
    """Extracted state update from DM response."""

    events_occurred: list[str]
    location_changed: str | None
    scene_completed: str | None
    flags_changed: dict[str, bool]

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "events_occurred": self.events_occurred,
            "location_changed": self.location_changed,
            "scene_completed": self.scene_completed,
            "flags_changed": self.flags_changed,
        }

    def has_changes(self) -> bool:
        """Check if there are any state changes."""
        return bool(
            self.events_occurred
            or self.location_changed
            or self.scene_completed
            or self.flags_changed
        )


class StateExtractor:
    """Extracts world state changes from DM responses using AI."""

    STATE_EXTRACTION_PROMPT = """You are a state extraction system for a D&D game. Analyze the Dungeon Master's response and extract world state changes.

CRITICAL RULES:
1. You MUST respond with ONLY valid JSON. No explanations, no markdown, no additional text.
2. For flags_changed: use ONLY flag IDs from the "Available Flags" list in the context.
3. If a new game state needs a flag that doesn't exist, create it using the SAME LANGUAGE as the DM's response (e.g., if DM writes in Russian, use "dver_otkryta" for "Дверь открыта").

Return this exact JSON structure:
{
  "events_occurred": [],
  "location_changed": null,
  "scene_completed": null,
  "flags_changed": {}
}

Guidelines:
- events_occurred: Array of key plot events as strings (e.g., ["npc_rescued", "combat_started"])
- location_changed: String location_id if moved to new location, otherwise null
- scene_completed: String scene_id if scene definitively ended, otherwise null
- flags_changed: Object with flag IDs as keys and boolean values. PREFER flags from the scenario. For NEW flags, use transliterated IDs in the SAME LANGUAGE as the DM's response.

Examples (Russian):
DM says "Вы входите в таверну": {"events_occurred": [], "location_changed": "tavern", "scene_completed": null, "flags_changed": {}}
DM says "Бой начинается!": {"events_occurred": ["combat_started"], "location_changed": null, "scene_completed": null, "flags_changed": {"combat_active": true}}
DM says "Дверь со скрипом открывается": {"events_occurred": [], "location_changed": null, "scene_completed": null, "flags_changed": {"dver_otkryta": true}}

Examples (English):
DM says "You enter the tavern": {"events_occurred": [], "location_changed": "tavern", "scene_completed": null, "flags_changed": {}}
DM says "Combat begins!": {"events_occurred": ["combat_started"], "location_changed": null, "scene_completed": null, "flags_changed": {"combat_active": true}}
DM says "The door creaks open": {"events_occurred": [], "location_changed": null, "scene_completed": null, "flags_changed": {"door_open": true}}

If unsure or no clear changes, return empty structure. Always return valid JSON."""

    def __init__(self) -> None:
        """Initialize state extractor with Anthropic Claude client."""
        settings = get_settings()
        self.api_key = settings.ANTHROPIC_API_KEY
        self.base_url = "https://api.anthropic.com/v1/messages"
        # Use Claude Haiku for fast, lightweight state extraction
        self.model = settings.model_state_extraction
        self.max_tokens = 500

        # Warn if API key is not set
        if not self.api_key:
            logger.warning(
                "ANTHROPIC_API_KEY not set. State extraction will fail. "
                "Consider setting it or state updates will be disabled."
            )

    async def extract_state_update(
        self,
        dm_response: str,
        current_world_state: dict[str, Any],
        scenario_content: dict[str, Any],
    ) -> StateUpdate:
        """Extract state changes from a DM response.

        Args:
            dm_response: The DM's response text
            current_world_state: Current world state
            scenario_content: The scenario content for reference

        Returns:
            StateUpdate with any changes
        """
        # Return empty state if API key is not configured
        if not self.api_key:
            logger.debug("Anthropic API key not set, skipping state extraction")
            return StateUpdate(
                events_occurred=[],
                location_changed=None,
                scene_completed=None,
                flags_changed={},
            )

        # Build context for the extraction
        context = self._build_context(current_world_state, scenario_content)

        user_prompt = f"""Context:
{context}

DM Response to analyze:
{dm_response}

Extract any state changes from this response."""

        try:
            result = await self._call_model(user_prompt)

            # Check if response has content
            if not result.get("content") or not result["content"]:
                logger.warning("State extraction API returned no content")
                return StateUpdate(
                    events_occurred=[],
                    location_changed=None,
                    scene_completed=None,
                    flags_changed={},
                )

            response_text = result["content"][0].get("text", "")

            # Check if content is empty
            if not response_text or response_text.strip() == "":
                logger.warning("State extraction returned empty content")
                return StateUpdate(
                    events_occurred=[],
                    location_changed=None,
                    scene_completed=None,
                    flags_changed={},
                )

            # Log the raw response for debugging
            logger.debug("State extraction raw response: %s", response_text[:200])

            json_text = _extract_json(response_text)

            # Check if json_text is empty after extraction
            if not json_text or json_text.strip() == "":
                logger.warning("State extraction JSON extraction resulted in empty string")
                return StateUpdate(
                    events_occurred=[],
                    location_changed=None,
                    scene_completed=None,
                    flags_changed={},
                )

            data = json.loads(json_text)

            return StateUpdate(
                events_occurred=data.get("events_occurred", []),
                location_changed=data.get("location_changed"),
                scene_completed=data.get("scene_completed"),
                flags_changed=data.get("flags_changed", {}),
            )

        except json.JSONDecodeError as e:
            logger.warning(
                "Failed to parse state extraction JSON: %s",
                str(e),
            )
            return StateUpdate(
                events_occurred=[],
                location_changed=None,
                scene_completed=None,
                flags_changed={},
            )
        except Exception as e:
            logger.error("Failed to extract state: %s", str(e), exc_info=True)
            return StateUpdate(
                events_occurred=[],
                location_changed=None,
                scene_completed=None,
                flags_changed={},
            )

    def _build_context(
        self,
        world_state: dict[str, Any],
        scenario_content: dict[str, Any],
    ) -> str:
        """Build context string for state extraction."""
        locations = [loc.get("id") for loc in scenario_content.get("locations", [])]
        scenes = []
        for act in scenario_content.get("acts", []):
            scenes.extend([s.get("id") for s in act.get("scenes", [])])
        
        # Build flags list with IDs and names
        flags = scenario_content.get("flags", [])
        flags_info = [f"- {f.get('id')}: {f.get('name')}" for f in flags] if flags else ["No flags defined"]

        return f"""Current World State:
- Current Act: {world_state.get("current_act")}
- Current Location: {world_state.get("current_location")}
- Completed Scenes: {world_state.get("completed_scenes", [])}
- Active Flags: {world_state.get("flags", {})}

Available Locations: {locations}
Available Scenes: {scenes}
Available Flags:
{chr(10).join(flags_info)}"""

    async def _call_model(self, user_prompt: str) -> dict:
        """Call Anthropic Claude API."""
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01",
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": user_prompt},
            ],
            "system": self.STATE_EXTRACTION_PROMPT,
            "max_tokens": self.max_tokens,
            "temperature": 0.1,  # Low temperature for consistent JSON
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.base_url, headers=headers, json=payload)
                response.raise_for_status()
                result = response.json()

                # Check if the response has the expected structure
                if "content" not in result or not result["content"]:
                    logger.error("Unexpected API response structure: %s", result)
                    raise ValueError("Invalid API response: missing 'content'")

                return result

        except httpx.HTTPStatusError as e:
            logger.error("Anthropic API HTTP error: status_code=%s, response=%s", e.response.status_code, e.response.text)
            raise
        except httpx.RequestError as e:
            logger.error("Anthropic API request error: %s", str(e))
            raise
        except Exception as e:
            logger.error("Unexpected error calling Anthropic API: %s", str(e))
            raise

    def apply_state_update(
        self,
        world_state: dict[str, Any],
        update: StateUpdate,
    ) -> dict[str, Any]:
        """Apply state update to world state.

        Args:
            world_state: Current world state
            update: State update to apply

        Returns:
            Updated world state
        """
        new_state = world_state.copy()

        # Update location if changed
        if update.location_changed:
            new_state["current_location"] = update.location_changed

        # Mark scene as completed
        if update.scene_completed:
            completed = new_state.get("completed_scenes", [])
            if update.scene_completed not in completed:
                completed.append(update.scene_completed)
            new_state["completed_scenes"] = completed

        # Update flags
        if update.flags_changed:
            flags = new_state.get("flags", {})
            flags.update(update.flags_changed)
            new_state["flags"] = flags

        return new_state
