"""State extractor for extracting world state changes from DM responses."""
import json
import logging
import re
from dataclasses import dataclass
from typing import Any

import httpx

from src.core.config import get_settings

logger = logging.getLogger(__name__)


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

    STATE_EXTRACTION_PROMPT = """Analyze the Dungeon Master's response and extract any world state changes as JSON.

Return ONLY a valid JSON object with this exact structure:
{
  "events_occurred": ["event_id", ...],
  "location_changed": "location_id or null",
  "scene_completed": "scene_id or null",
  "flags_changed": {"flag_name": true/false, ...}
}

Guidelines:
- events_occurred: Key plot events (e.g., "npc_rescued", "combat_started", "door_opened")
- location_changed: Only if characters moved to a new location (use location_id from scenario)
- scene_completed: Only if a scene has definitively ended
- flags_changed: Important story flags that changed state

If no changes occurred, return empty arrays/objects.
Always return valid JSON, nothing else."""

    def __init__(self) -> None:
        """Initialize state extractor with OpenRouter client."""
        settings = get_settings()
        self.api_key = settings.OPENROUTER_API_KEY
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"
        # Use a fast model for state extraction
        self.model = "nousresearch/deephermes-3-llama-3-8b-preview:free"
        self.max_tokens = 500

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
        # Build context for the extraction
        context = self._build_context(current_world_state, scenario_content)

        user_prompt = f"""Context:
{context}

DM Response to analyze:
{dm_response}

Extract any state changes from this response."""

        try:
            result = await self._call_model(user_prompt)
            response_text = result["choices"][0]["message"]["content"]
            json_text = _extract_json(response_text)
            data = json.loads(json_text)

            return StateUpdate(
                events_occurred=data.get("events_occurred", []),
                location_changed=data.get("location_changed"),
                scene_completed=data.get("scene_completed"),
                flags_changed=data.get("flags_changed", {}),
            )

        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse state extraction JSON: {e}")
            return StateUpdate(
                events_occurred=[],
                location_changed=None,
                scene_completed=None,
                flags_changed={},
            )
        except Exception as e:
            logger.error(f"Failed to extract state: {e}")
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

        return f"""Current World State:
- Current Act: {world_state.get("current_act")}
- Current Location: {world_state.get("current_location")}
- Completed Scenes: {world_state.get("completed_scenes", [])}
- Active Flags: {world_state.get("flags", {})}

Available Locations: {locations}
Available Scenes: {scenes}"""

    async def _call_model(self, user_prompt: str) -> dict:
        """Call OpenRouter API."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.STATE_EXTRACTION_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.1,  # Low temperature for consistent JSON
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(self.base_url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()

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
