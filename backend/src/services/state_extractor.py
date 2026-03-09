"""State extractor for extracting world state changes from DM responses."""
import json
import re
import time
from dataclasses import dataclass
from typing import Any

import httpx

from src.core.config import get_settings
from src.core.logging import get_logger

logger = get_logger(__name__)

# ── Orange terminal colors for outgoing OpenRouter API calls ──────────────────
_O  = "\033[38;5;214m"   # orange
_OB = "\033[1;38;5;214m" # bold orange
_OD = "\033[38;5;172m"   # dim orange
_G  = "\033[38;5;82m"    # green  (success)
_R  = "\033[38;5;196m"   # red    (error)
_X  = "\033[0m"          # reset


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
    flags_changed: dict[str, dict[str, Any]]  # {id: {"value": bool, "label": str}}

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
2. For flags_changed: PREFER flag IDs from the "Available Flags" list in the context.
3. Each flag in flags_changed must have: {"value": bool, "label": "Human readable name in DM's language"}
4. For NEW flags: use a simple snake_case ID, and a human-readable label in the SAME LANGUAGE as the DM's response.

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
- flags_changed: Object where each key is a flag ID and value is {"value": bool, "label": "readable name"}

Examples (Russian):
DM says "Вы входите в таверну": {"events_occurred": [], "location_changed": "tavern", "scene_completed": null, "flags_changed": {}}
DM says "Бой начинается!": {"events_occurred": ["combat_started"], "location_changed": null, "scene_completed": null, "flags_changed": {"combat_active": {"value": true, "label": "Бой активен"}}}
DM says "Дверь со скрипом открывается": {"events_occurred": [], "location_changed": null, "scene_completed": null, "flags_changed": {"door_open": {"value": true, "label": "Дверь открыта"}}}
DM says "Вы нашли ключ": {"events_occurred": ["key_found"], "location_changed": null, "scene_completed": null, "flags_changed": {"key_found": {"value": true, "label": "Ключ найден"}}}

Examples (English):
DM says "You enter the tavern": {"events_occurred": [], "location_changed": "tavern", "scene_completed": null, "flags_changed": {}}
DM says "Combat begins!": {"events_occurred": ["combat_started"], "location_changed": null, "scene_completed": null, "flags_changed": {"combat_active": {"value": true, "label": "Combat Active"}}}
DM says "The door creaks open": {"events_occurred": [], "location_changed": null, "scene_completed": null, "flags_changed": {"door_open": {"value": true, "label": "Door Open"}}}

If unsure or no clear changes, return empty structure. Always return valid JSON."""

    def __init__(self) -> None:
        """Initialize state extractor based on AI_PROVIDER setting."""
        settings = get_settings()
        self.provider = settings.ai_provider.lower()
        self.max_tokens = settings.max_tokens_state_extraction

        if self.provider == "lmstudio":
            self.lmstudio_base_url = settings.lmstudio_base_url
            self.model = settings.lmstudio_model
            self.api_key = ""
            logger.info("StateExtractor using LM Studio: model=%s", self.model)
        elif self.provider == "ollama":
            self.ollama_base_url = settings.ollama_base_url.rstrip("/") + "/v1/chat/completions"
            self.model = settings.ollama_model
            self.api_key = ""
            logger.info("StateExtractor using Ollama: model=%s", self.model)
        elif self.provider == "openrouter":
            self.openrouter_api_key = settings.openrouter_api_key
            self.openrouter_base_url = settings.openrouter_base_url
            self.model = settings.openrouter_model
            self.api_key = settings.openrouter_api_key
            logger.info("StateExtractor using OpenRouter: model=%s", self.model)
            if not self.openrouter_api_key:
                logger.warning(
                    "OPENROUTER_API_KEY not set. State extraction will fail."
                )
        else:
            self.api_key = settings.ANTHROPIC_API_KEY
            self.base_url = "https://api.anthropic.com/v1/messages"
            self.model = settings.model_state_extraction
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
        # Return empty state if API key is not configured (skip for Ollama/LM Studio)
        if self.provider not in ("ollama", "lmstudio", "openrouter") and not self.api_key:
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
            logger.info("State extraction raw response: %s", response_text[:500])

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

        # Format active flags for display
        active_flags = world_state.get("flags", {})
        active_flags_display = {
            fid: fdata.get("value") if isinstance(fdata, dict) else fdata
            for fid, fdata in active_flags.items()
        }

        return f"""Current World State:
- Current Act: {world_state.get("current_act")}
- Current Location: {world_state.get("current_location")}
- Completed Scenes: {world_state.get("completed_scenes", [])}
- Active Flags: {active_flags_display}

Available Locations: {locations}
Available Scenes: {scenes}
Available Flags:
{chr(10).join(flags_info)}"""

    async def _call_model(self, user_prompt: str) -> dict:
        """Call AI provider (Anthropic, Ollama, LM Studio, or OpenRouter) for state extraction."""
        if self.provider == "lmstudio":
            return await self._call_lmstudio(user_prompt)
        if self.provider == "ollama":
            return await self._call_ollama(user_prompt)
        if self.provider == "openrouter":
            return await self._call_openrouter(user_prompt)
        return await self._call_anthropic(user_prompt)

    async def _call_anthropic(self, user_prompt: str) -> dict:
        """Call Anthropic Claude API."""
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01",
        }
        payload = {
            "model": self.model,
            "messages": [{"role": "user", "content": user_prompt}],
            "system": self.STATE_EXTRACTION_PROMPT,
            "max_tokens": self.max_tokens,
            "temperature": 0.1,
        }
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.base_url, headers=headers, json=payload)
                response.raise_for_status()
                result = response.json()
                if "content" not in result or not result["content"]:
                    logger.error("Unexpected Anthropic API response: %s", result)
                    raise ValueError("Invalid API response: missing 'content'")
                return result
        except httpx.HTTPStatusError as e:
            logger.error("Anthropic API HTTP error: status_code=%s, response=%s", e.response.status_code, e.response.text)
            raise
        except httpx.RequestError as e:
            logger.error("Anthropic API request error: %s", str(e))
            raise

    async def _call_lmstudio(self, user_prompt: str) -> dict:
        """Call LM Studio chat API for state extraction.

        Note: LM Studio doesn't support "system" role, so system prompt is combined with user message.
        """
        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": f"{self.STATE_EXTRACTION_PROMPT}\n\n{user_prompt}"},
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.1,
            "stream": False,
        }
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.lmstudio_base_url, json=payload)
                response.raise_for_status()
                data = response.json()
                # LM Studio returns Anthropic-style response format
                if "content" in data and isinstance(data["content"], list):
                    content_text = data["content"][0].get("text", "")
                else:
                    # Fallback for OpenAI format
                    content_text = data["choices"][0]["message"]["content"]
                return {"content": [{"text": content_text}]}
        except httpx.HTTPStatusError as e:
            logger.error("LM Studio API HTTP error: status_code=%s, response=%s", e.response.status_code, e.response.text)
            raise
        except httpx.RequestError as e:
            logger.error("LM Studio API request error: %s", str(e))
            raise

    async def _call_ollama(self, user_prompt: str) -> dict:
        """Call Ollama via OpenAI-compatible API.

        Note: System prompt is combined with user message for compatibility.
        """
        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": f"{self.STATE_EXTRACTION_PROMPT}\n\n{user_prompt}"},
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.1,
            "stream": False,
        }
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.ollama_base_url, json=payload)
                response.raise_for_status()
                data = response.json()
                content_text = data["choices"][0]["message"]["content"]
                # Return Anthropic-compatible shape
                return {"content": [{"text": content_text}]}
        except httpx.HTTPStatusError as e:
            logger.error("Ollama API HTTP error: status_code=%s, response=%s", e.response.status_code, e.response.text)
            raise
        except httpx.RequestError as e:
            logger.error("Ollama API request error: %s", str(e))
            raise

    async def _call_openrouter(self, user_prompt: str) -> dict:
        """Call OpenRouter API for state extraction."""
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.STATE_EXTRACTION_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.1,
        }
        headers = {
            "Authorization": f"Bearer {self.openrouter_api_key}",
            "Content-Type": "application/json",
        }
        print(
            f"{_O}┌─{_X} {_OB}▶ OpenRouter REQUEST{_X} [state_extractor]  "
            f"{_OD}model={_X}{self.model}  "
            f"{_OD}max_tokens={_X}{self.max_tokens}\n"
            f"{_O}│{_X}  {_OD}url={_X}{self.openrouter_base_url}"
        )
        t0 = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(self.openrouter_base_url, headers=headers, json=payload)
                response.raise_for_status()
                data = response.json()
                content_text = data["choices"][0]["message"]["content"]
                usage = data.get("usage", {})
                in_tok  = usage.get("prompt_tokens", 0)
                out_tok = usage.get("completion_tokens", 0)
                elapsed = (time.perf_counter() - t0) * 1000
                print(
                    f"{_O}└─{_X} {_G}✓ {response.status_code}{_X}  "
                    f"{_OD}in={_X}{in_tok} tok  "
                    f"{_OD}out={_X}{out_tok} tok  "
                    f"{_OD}⏱ {elapsed:.0f} ms{_X}"
                )
                return {"content": [{"text": content_text}]}
        except httpx.HTTPStatusError as e:
            elapsed = (time.perf_counter() - t0) * 1000
            print(f"{_O}└─{_X} {_R}✗ {e.response.status_code}  error={e}{_X}  {_OD}⏱ {elapsed:.0f} ms{_X}")
            logger.error("OpenRouter API HTTP error: status_code=%s, response=%s", e.response.status_code, e.response.text)
            raise
        except httpx.RequestError as e:
            elapsed = (time.perf_counter() - t0) * 1000
            print(f"{_O}└─{_X} {_R}✗ request error={e}{_X}  {_OD}⏱ {elapsed:.0f} ms{_X}")
            logger.error("OpenRouter API request error: %s", str(e))
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

        # Update flags - merge new flags with existing ones
        if update.flags_changed:
            flags = new_state.get("flags", {})
            for flag_id, flag_data in update.flags_changed.items():
                if isinstance(flag_data, dict):
                    # New format: {"value": bool, "label": str}
                    flags[flag_id] = flag_data
                else:
                    # Legacy format: plain bool - wrap it
                    flags[flag_id] = {"value": bool(flag_data), "label": flag_id}
            new_state["flags"] = flags

        return new_state
