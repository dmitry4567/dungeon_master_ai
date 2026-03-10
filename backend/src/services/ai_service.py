"""AI service for Anthropic Claude API integration with streaming support."""
import asyncio
import json
import re
import time
from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import httpx
from fastapi import HTTPException

from src.core.config import get_settings
from src.core.logging import get_logger

# Retry configuration for AI provider unavailability
_MAX_RETRIES = 3
_RETRY_DELAYS = [1.0, 2.0, 4.0]  # Exponential backoff in seconds
_RETRY_STATUS_CODES = {429, 500, 502, 503, 504}  # Retryable HTTP status codes

logger = get_logger(__name__)

# ── Orange terminal colors for outgoing OpenRouter API calls ──────────────────
_O  = "\033[38;5;214m"   # orange
_OB = "\033[1;38;5;214m" # bold orange
_OD = "\033[38;5;172m"   # dim orange
_G  = "\033[38;5;82m"    # green  (success)
_R  = "\033[38;5;196m"   # red    (error)
_X  = "\033[0m"          # reset


def _or_log_request(url: str, model: str, stream: bool, max_tokens: int) -> None:
    print(
        f"{_O}┌─{_X} {_OB}▶ OpenRouter REQUEST{_X}  "
        f"{_OD}model={_X}{model}  "
        f"{_OD}stream={_X}{stream}  "
        f"{_OD}max_tokens={_X}{max_tokens}\n"
        f"{_O}│{_X}  {_OD}url={_X}{url}"
    )


def _or_log_response(status: int, input_tokens: int, output_tokens: int, elapsed_ms: float) -> None:
    color = _G if status < 400 else _R
    icon  = "✓" if status < 400 else "✗"
    print(
        f"{_O}└─{_X} {color}{icon} {status}{_X}  "
        f"{_OD}in={_X}{input_tokens} tok  "
        f"{_OD}out={_X}{output_tokens} tok  "
        f"{_OD}⏱ {elapsed_ms:.0f} ms{_X}"
    )


def _or_log_stream_start(model: str) -> None:
    print(
        f"{_O}┌─{_X} {_OB}▶ OpenRouter STREAM{_X}  {_OD}model={_X}{model}"
    )


def _or_log_stream_done(chunks: int, elapsed_ms: float) -> None:
    print(
        f"{_O}└─{_X} {_G}✓ stream done{_X}  "
        f"{_OD}chunks={_X}{chunks}  "
        f"{_OD}⏱ {elapsed_ms:.0f} ms{_X}"
    )


def _or_log_error(exc: Exception, elapsed_ms: float) -> None:
    print(
        f"{_O}└─{_X} {_R}✗ OpenRouter ERROR{_X}  "
        f"{_OD}error={_X}{exc}  "
        f"{_OD}⏱ {elapsed_ms:.0f} ms{_X}"
    )


def _extract_json(text: str) -> str:
    """Extract JSON from text, handling markdown code blocks and truncated responses.

    Handles:
    - ```json ... ``` blocks (complete)
    - ```json ... (truncated, no closing ```)
    - Raw JSON without code blocks
    """
    text = text.strip()

    # Try complete code block first
    match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if match:
        return match.group(1).strip()

    # Try incomplete code block (truncated response without closing ```)
    match = re.search(r"```(?:json)?\s*([\s\S]+)", text)
    if match:
        return match.group(1).strip()

    # No code block — return as-is
    return text


def _repair_json(text: str) -> str:
    """Attempt to repair common JSON issues produced by LLMs.

    Fixes:
    - Trailing commas before } or ]
    - Single-quoted strings (Python-style)
    """
    # Remove trailing commas before } or ]
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return text


@dataclass
class TokenUsage:
    """Token usage tracking."""

    input_tokens: int
    output_tokens: int
    model: str
    timestamp: datetime

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens


class AIService:
    """Service for AI generation using Anthropic Claude or Ollama with streaming support."""

    def __init__(self) -> None:
        """Initialize AI service based on AI_PROVIDER setting."""
        settings = get_settings()
        self.provider = settings.ai_provider.lower()
        self._usage_log: list[TokenUsage] = []

        # Per-task max tokens from config
        self.max_tokens_dm_response = settings.max_tokens_dm_response
        self.max_tokens_scenario_generation = settings.max_tokens_scenario_generation
        self.max_tokens_scenario_refinement = settings.max_tokens_scenario_refinement
        # Default max_tokens (used by _call_model fallback)
        self.max_tokens = self.max_tokens_dm_response

        if self.provider == "lmstudio":
            self.lmstudio_base_url = settings.lmstudio_base_url
            # Extract base URL without /v1/chat/completions for other API calls
            base = settings.lmstudio_base_url
            if "/v1/chat/completions" in base:
                self.lmstudio_api_base = base.replace("/v1/chat/completions", "")
            else:
                self.lmstudio_api_base = base.rstrip("/")
            lmstudio_model = settings.lmstudio_model
            self.lmstudio_context_length = settings.lmstudio_context_length
            self.lmstudio_auto_load = settings.lmstudio_auto_load
            self.model_dm_response = lmstudio_model
            self.model_scenario_generation = lmstudio_model
            self.model_scenario_refinement = lmstudio_model
            self.model = lmstudio_model
            logger.info(
                "LM Studio initialized: model=%s, base_url=%s, api_base=%s, context_length=%s, auto_load=%s",
                lmstudio_model, self.lmstudio_base_url, self.lmstudio_api_base, self.lmstudio_context_length, self.lmstudio_auto_load,
            )
        elif self.provider == "ollama":
            self.ollama_base_url = settings.ollama_base_url.rstrip("/") + "/v1/chat/completions"
            ollama_model = settings.ollama_model
            self.model_dm_response = ollama_model
            self.model_scenario_generation = ollama_model
            self.model_scenario_refinement = ollama_model
            self.model = ollama_model
            logger.info(
                "Ollama initialized: model=%s, base_url=%s",
                ollama_model, self.ollama_base_url,
            )
        elif self.provider == "openrouter":
            self.openrouter_api_key = settings.openrouter_api_key
            self.openrouter_base_url = settings.openrouter_base_url
            openrouter_model = settings.openrouter_model
            self.model_dm_response = openrouter_model
            self.model_scenario_generation = openrouter_model
            self.model_scenario_refinement = openrouter_model
            self.model = openrouter_model
            logger.info(
                "OpenRouter initialized: model=%s, base_url=%s",
                openrouter_model, self.openrouter_base_url,
            )
        else:
            self.api_key = settings.ANTHROPIC_API_KEY
            self.base_url = "https://api.anthropic.com/v1/messages"
            self.model_dm_response = settings.model_dm_response
            self.model_scenario_generation = settings.model_scenario_generation
            self.model_scenario_refinement = settings.model_scenario_refinement
            self.model = self.model_dm_response
            logger.info(
                "Anthropic Claude initialized: "
                "dm=%s(max=%s), scenario_gen=%s(max=%s), scenario_refine=%s(max=%s)",
                self.model_dm_response, self.max_tokens_dm_response,
                self.model_scenario_generation, self.max_tokens_scenario_generation,
                self.model_scenario_refinement, self.max_tokens_scenario_refinement,
            )

    def _build_dm_system_prompt(
        self,
        scenario_content: dict[str, Any],
        world_state: dict[str, Any],
        players: list[dict[str, Any]],
    ) -> str:
        """Build the Dungeon Master system prompt with full context.

        Args:
            scenario_content: The scenario content (acts, NPCs, locations, etc.)
            world_state: Current world state
            players: List of player information with their characters

        Returns:
            Complete system prompt for the DM
        """
        # Build player info section
        player_info = []
        for p in players:
            char = p.get("character", {})
            player_info.append(
                f"- {char.get('name', 'Unknown')} ({char.get('race', '')} {char.get('class', '')} "
                f"Level {char.get('level', 1)}) played by {p.get('name', 'Unknown')}"
            )
        players_section = "\n".join(player_info) if player_info else "No players"

        # Build current location info
        current_location_id = world_state.get("current_location")
        location_info = "Unknown"
        for loc in scenario_content.get("locations", []):
            if loc.get("id") == current_location_id:
                location_info = f"{loc.get('name', 'Unknown')} - {loc.get('atmosphere', '')}"
                break

        # Build NPC reference (limit to 5 to save tokens)
        npcs_section = []
        for npc in scenario_content.get("npcs", [])[:5]:
            npcs_section.append(
                f"- {npc.get('name')}: {npc.get('role')} - {npc.get('personality')}"
            )
        npcs_text = "\n".join(npcs_section) if npcs_section else "No NPCs defined"

        # Build current act/scene info
        current_act_id = world_state.get("current_act", "act_1")
        current_scene_info = "Session start"
        for act in scenario_content.get("acts", []):
            if act.get("id") == current_act_id:
                for scene in act.get("scenes", []):
                    current_scene_info = scene.get("description_for_ai", "")
                    break
                break

        world_lore = scenario_content.get("world_lore", "A mysterious world awaits...")
        world_lore_short = world_lore[:800] + "..." if len(world_lore) > 800 else world_lore

        return f"""You are an expert Dungeon Master for a D&D 5e game session.
Respond in the SAME LANGUAGE as the player's message.

## Scenario: {scenario_content.get("title", "Adventure")} | Tone: {scenario_content.get("tone", "heroic")} | Difficulty: {scenario_content.get("difficulty", "intermediate")}

## World Lore
{world_lore_short}

## Location: {location_info}
## Scene: {current_scene_info}

## NPCs
{npcs_text}

## Players
{players_section}

## World State
- Act: {world_state.get("current_act", "act_1")}
- Completed: {", ".join(world_state.get("completed_scenes", [])) or "None"}
- Flags: {self._compact_flags(world_state.get("flags", {}))}
- Combat: {world_state.get("combat_active", False)}

## Your Role
1. Narrate the story based on player actions
2. Play NPCs in character with their defined personalities and speech styles
3. Request dice rolls when appropriate (skill checks, combat, saves)
4. Keep content appropriate for all audiences (no graphic violence or sexual content)
5. Follow D&D 5e rules for mechanics
6. Be descriptive and immersive in your narration
7. React to player creativity while keeping the story on track

## Dice Roll Format - CRITICAL RULES
When a player attempts an action that requires a dice roll (attack, skill check, saving throw):

1. STOP your narration BEFORE describing the outcome
2. Describe the attempt/setup, but NOT the result
3. End your message with EXACTLY ONE [DICE:...] marker at the VERY END
4. DO NOT write ANY text after the [DICE:...] marker
5. DO NOT ask the player to roll dice in natural language - ONLY use the [DICE:...] format

Format: [DICE: d20+modifier DC:difficulty Skill:SkillName Reason:Description]

CORRECT example:
"You raise your sword and swing at the guard, aiming for a gap in his armor.
[DICE: d20+5 DC:15 Reason:Attack roll against the guard]"

WRONG - dice marker not at the end:
"[DICE: d20+5 DC:15 Reason:Attack] You swing your sword..."

WRONG - asking to roll in natural language:
"You swing at the guard. Roll a d20 for the attack."

## After Receiving Dice Results
When you receive a message like "[DICE RESULT: d20+5 rolled 18 = 23 vs DC 15 - SUCCESS]":
- This means the player ALREADY rolled the dice
- DO NOT ask for another roll
- Describe the OUTCOME based on the result (success or failure)
- Continue the narrative normally

Remember: ALWAYS respond in the same language the player uses!"""

    def _compact_flags(self, flags: dict) -> str:
        """Return only active (True) flags as a compact string to save tokens."""
        active = {
            fid: (fdata.get("label", fid) if isinstance(fdata, dict) else fid)
            for fid, fdata in flags.items()
            if (fdata.get("value", False) if isinstance(fdata, dict) else bool(fdata))
        }
        if not active:
            return "none"
        return ", ".join(active.values())

    async def _call_model(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
        model: str | None = None,
        max_tokens: int | None = None,
        timeout: float | None = None,
    ) -> dict | AsyncIterator[str]:
        """Internal helper — routes to Anthropic, Ollama, or LM Studio based on AI_PROVIDER."""
        if self.provider == "lmstudio":
            return await self._call_lmstudio(
                system_prompt, messages, stream=stream,
                model=model or self.model,
                max_tokens=max_tokens or self.max_tokens,
                timeout=timeout,
            )
        if self.provider == "ollama":
            return await self._call_ollama(
                system_prompt, messages, stream=stream,
                model=model or self.model,
                max_tokens=max_tokens or self.max_tokens,
                timeout=timeout,
            )
        if self.provider == "openrouter":
            return await self._call_openrouter(
                system_prompt, messages, stream=stream,
                model=model or self.model,
                max_tokens=max_tokens or self.max_tokens,
                timeout=timeout,
            )
        return await self._call_anthropic(system_prompt, messages, stream=stream, model=model, max_tokens=max_tokens, timeout=timeout)

    async def _call_anthropic(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
        model: str | None = None,
        max_tokens: int | None = None,
        timeout: float | None = None,
    ) -> dict | AsyncIterator[str]:
        """Call Anthropic Claude API."""
        selected_model = model or self.model
        selected_max_tokens = max_tokens or self.max_tokens
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01",
        }

        claude_messages = [{"role": msg["role"], "content": msg["content"]} for msg in messages]

        payload = {
            "model": selected_model,
            "messages": claude_messages,
            "system": system_prompt,
            "max_tokens": selected_max_tokens,
            "temperature": 0.8,
            "stream": stream,
        }

        if stream:
            return self._stream_response(headers, payload, timeout)
        else:
            return await self._call_with_retry(headers, payload, timeout)

    async def _check_lmstudio_model_loaded(self, model: str) -> bool:
        """Check if a model is currently loaded in LM Studio.
        
        Args:
            model: Model name to check
            
        Returns:
            True if model is loaded, False otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Use the LM Studio API endpoint for listing loaded models
                response = await client.get(f"{self.lmstudio_api_base}/v1/models")
                if response.status_code == 200:
                    data = response.json()
                    models = data.get("data", [])
                    for m in models:
                        model_id = m.get("id", "")
                        # Check if the model is loaded (either exact match or contains the model name)
                        if model_id == model or model in model_id:
                            logger.info("Model %s is loaded (id: %s)", model, model_id)
                            return True
                    logger.info("Model %s not found in loaded models: %s", model, [m.get("id") for m in models])
                    return False
                logger.warning("Failed to check LM Studio models: Status %s", response.status_code)
                return False
        except Exception as e:
            logger.warning("Failed to check LM Studio model status: %s", str(e))
            return False

    async def _load_lmstudio_model(self, model: str, context_length: int | None = None) -> bool:
        """Load a model in LM Studio via its API.
        
        Args:
            model: Model name/path to load
            context_length: Context window size (optional)
            
        Returns:
            True if model loaded successfully, False otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Build load configuration
                payload = {
                    "model": model,
                }
                if context_length:
                    payload["context_length"] = context_length
                
                # Add recommended defaults for better performance
                payload["flash_attention"] = True
                payload["echo_load_config"] = True
                
                logger.info("Loading LM Studio model: %s (context_length=%s)", model, context_length)
                
                # Use the correct LM Studio endpoint: /api/v1/models/load
                # lmstudio_api_base is like http://localhost:1234
                load_url = f"{self.lmstudio_api_base}/api/v1/models/load"
                logger.info("POST to %s with payload: %s", load_url, payload)
                
                response = await client.post(load_url, json=payload)
                
                if response.status_code in (200, 201):
                    logger.info("LM Studio model loaded successfully: %s", model)
                    return True
                    
                logger.error("Failed to load LM Studio model: %s - Status: %s, Response: %s", 
                           model, response.status_code, response.text[:200])
                return False
        except httpx.ConnectError as e:
            logger.error("Cannot connect to LM Studio at %s: %s. Make sure LM Studio is running.", 
                        self.lmstudio_api_base, str(e))
            return False
        except Exception as e:
            logger.error("Error loading LM Studio model: %s", str(e))
            return False

    async def _ensure_lmstudio_model_ready(self, model: str, context_length: int) -> None:
        """Ensure LM Studio model is loaded, loading it if necessary.
        
        Args:
            model: Model name to ensure is loaded
            context_length: Context window size
        """
        if not self.lmstudio_auto_load:
            logger.debug("LM Studio auto-load disabled, skipping model check")
            return
            
        logger.info("Checking if LM Studio model is loaded: %s", model)
        
        # Check if model is already loaded
        is_loaded = await self._check_lmstudio_model_loaded(model)
        
        if is_loaded:
            logger.info("LM Studio model already loaded: %s", model)
            return
        
        # Model not loaded, attempt to load it
        logger.warning("LM Studio model not loaded, attempting to load: %s", model)
        loaded = await self._load_lmstudio_model(model, context_length)
        
        if not loaded:
            logger.error(
                "Failed to auto-load LM Studio model: %s. "
                "Please load the model manually in LM Studio.",
                model
            )

    async def _call_lmstudio(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
        model: str | None = None,
        max_tokens: int | None = None,
        timeout: float | None = None,
    ) -> dict | AsyncIterator[str]:
        """Call LM Studio via its chat API.

        Note: LM Studio doesn't support "system" role in messages array.
        System prompt is combined with the first user message instead.
        """
        selected_model = model or self.model
        selected_max_tokens = max_tokens or self.max_tokens

        # Ensure model is loaded before making requests
        await self._ensure_lmstudio_model_ready(selected_model, self.lmstudio_context_length)

        lm_messages = [{"role": msg["role"], "content": msg["content"]} for msg in messages]

        # Combine system prompt with first user message since LM Studio doesn't support system role
        if lm_messages:
            if lm_messages[0]["role"] == "user":
                lm_messages[0]["content"] = f"{system_prompt}\n\n{lm_messages[0]['content']}"
            else:
                lm_messages.insert(0, {"role": "user", "content": system_prompt})
        else:
            lm_messages = [{"role": "user", "content": system_prompt}]

        payload = {
            "model": selected_model,
            "messages": lm_messages,
            "max_tokens": selected_max_tokens,
            "temperature": 0.8,
            "stream": stream,
        }

        if stream:
            return self._stream_lmstudio(payload, timeout)

        request_timeout = timeout or 120.0
        async with httpx.AsyncClient(timeout=request_timeout) as client:
            response = await client.post(self.lmstudio_base_url, json=payload)
            response.raise_for_status()
            data = response.json()

            # LM Studio returns Anthropic-style response format
            if "content" in data and isinstance(data["content"], list):
                content_text = data["content"][0].get("text", "")
                stop_reason = data.get("stop_reason", "end_turn")
            else:
                # Fallback for OpenAI format
                content_text = data["choices"][0]["message"]["content"]
                finish_reason = data["choices"][0].get("finish_reason", "stop")
                # Normalize to Anthropic-style stop_reason
                stop_reason = "max_tokens" if finish_reason == "length" else "end_turn"

            usage = data.get("usage", {})
            self._log_usage(usage.get("input_tokens", 0), usage.get("output_tokens", 0))
            return {"content": [{"text": content_text}], "stop_reason": stop_reason}

    async def _stream_lmstudio(self, payload: dict, timeout: float | None = None) -> AsyncIterator[str]:
        """Stream response from LM Studio chat API.

        LM Studio returns Anthropic-style streaming format with delta.text.
        """
        request_timeout = timeout or 120.0
        async with httpx.AsyncClient(timeout=request_timeout) as client:
            async with client.stream("POST", self.lmstudio_base_url, json=payload) as response:
                response.raise_for_status()
                buffer = ""
                async for chunk_bytes in response.aiter_bytes():
                    buffer += chunk_bytes.decode("utf-8", errors="ignore")
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if not line or not line.startswith("data: "):
                            continue
                        data = line[6:]
                        if data == "[DONE]":
                            return
                        try:
                            chunk = json.loads(data)
                            # LM Studio returns Anthropic-style format with delta.text
                            if "delta" in chunk:
                                content = chunk.get("delta", {}).get("text", "")
                            else:
                                # Fallback for OpenAI format
                                content = chunk["choices"][0].get("delta", {}).get("content", "")
                            if content:
                                yield content
                        except (json.JSONDecodeError, KeyError):
                            continue

    async def _call_ollama(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
        model: str | None = None,
        max_tokens: int | None = None,
        timeout: float | None = None,
    ) -> dict | AsyncIterator[str]:
        """Call Ollama via OpenAI-compatible API.

        Note: System prompt is combined with the first user message for compatibility.
        """
        selected_model = model or self.model
        selected_max_tokens = max_tokens or self.max_tokens

        ollama_messages = [{"role": msg["role"], "content": msg["content"]} for msg in messages]

        # Combine system prompt with first user message for compatibility
        if ollama_messages:
            if ollama_messages[0]["role"] == "user":
                ollama_messages[0]["content"] = f"{system_prompt}\n\n{ollama_messages[0]['content']}"
            else:
                ollama_messages.insert(0, {"role": "user", "content": system_prompt})
        else:
            ollama_messages = [{"role": "user", "content": system_prompt}]

        payload = {
            "model": selected_model,
            "messages": ollama_messages,
            "max_tokens": selected_max_tokens,
            "temperature": 0.8,
            "stream": stream,
        }

        if stream:
            return self._stream_ollama(payload, timeout)

        request_timeout = timeout or 120.0
        async with httpx.AsyncClient(timeout=request_timeout) as client:
            response = await client.post(self.ollama_base_url, json=payload)
            response.raise_for_status()
            data = response.json()
            # Convert to Anthropic-compatible response shape
            content_text = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            self._log_usage(usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0))
            return {"content": [{"text": content_text}], "stop_reason": "end_turn"}

    async def _call_openrouter(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
        model: str | None = None,
        max_tokens: int | None = None,
        timeout: float | None = None,
    ) -> dict | AsyncIterator[str]:
        """Call OpenRouter via OpenAI-compatible API."""
        selected_model = model or self.model
        selected_max_tokens = max_tokens or self.max_tokens

        or_messages = [{"role": "system", "content": system_prompt}]
        or_messages += [{"role": msg["role"], "content": msg["content"]} for msg in messages]

        payload = {
            "model": selected_model,
            "messages": or_messages,
            "max_tokens": selected_max_tokens,
            "temperature": 0.8,
            "stream": stream,
        }

        if stream:
            return self._stream_openrouter(payload, timeout, selected_model)

        request_timeout = timeout or 120.0
        headers = {
            "Authorization": f"Bearer {self.openrouter_api_key}",
            "Content-Type": "application/json",
        }
        _or_log_request(self.openrouter_base_url, selected_model, stream=False, max_tokens=selected_max_tokens)
        t0 = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=request_timeout) as client:
                response = await client.post(self.openrouter_base_url, headers=headers, json=payload)
                response.raise_for_status()
                data = response.json()
                content_text = data["choices"][0]["message"]["content"]
                finish_reason = data["choices"][0].get("finish_reason", "stop")
                stop_reason = "max_tokens" if finish_reason == "length" else "end_turn"
                usage = data.get("usage", {})
                in_tok  = usage.get("prompt_tokens", 0)
                out_tok = usage.get("completion_tokens", 0)
                self._log_usage(in_tok, out_tok)
                _or_log_response(response.status_code, in_tok, out_tok, (time.perf_counter() - t0) * 1000)
                return {"content": [{"text": content_text}], "stop_reason": stop_reason}
        except Exception as exc:
            _or_log_error(exc, (time.perf_counter() - t0) * 1000)
            raise

    async def _stream_openrouter(self, payload: dict, timeout: float | None = None, model: str | None = None) -> AsyncIterator[str]:
        """Stream response from OpenRouter API."""
        request_timeout = timeout or 120.0
        headers = {
            "Authorization": f"Bearer {self.openrouter_api_key}",
            "Content-Type": "application/json",
        }
        _or_log_stream_start(model or payload.get("model", "?"))
        t0 = time.perf_counter()
        chunks = 0
        try:
            async with httpx.AsyncClient(timeout=request_timeout) as client:
                async with client.stream("POST", self.openrouter_base_url, headers=headers, json=payload) as response:
                    response.raise_for_status()
                    buffer = ""
                    async for chunk_bytes in response.aiter_bytes():
                        buffer += chunk_bytes.decode("utf-8", errors="ignore")
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            line = line.strip()
                            if not line or not line.startswith("data: "):
                                continue
                            data = line[6:]
                            if data == "[DONE]":
                                _or_log_stream_done(chunks, (time.perf_counter() - t0) * 1000)
                                return
                            try:
                                chunk = json.loads(data)
                                choices = chunk.get("choices", [])
                                if not choices:
                                    continue
                                content = choices[0].get("delta", {}).get("content", "")
                                if content:
                                    chunks += 1
                                    yield content
                            except (json.JSONDecodeError, KeyError, IndexError):
                                continue
            _or_log_stream_done(chunks, (time.perf_counter() - t0) * 1000)
        except Exception as exc:
            _or_log_error(exc, (time.perf_counter() - t0) * 1000)
            raise

    async def _stream_ollama(self, payload: dict, timeout: float | None = None) -> AsyncIterator[str]:
        """Stream response from Ollama OpenAI-compatible API."""
        request_timeout = timeout or 120.0
        async with httpx.AsyncClient(timeout=request_timeout) as client:
            async with client.stream("POST", self.ollama_base_url, json=payload) as response:
                response.raise_for_status()
                buffer = ""
                async for chunk_bytes in response.aiter_bytes():
                    buffer += chunk_bytes.decode("utf-8", errors="ignore")
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if not line or not line.startswith("data: "):
                            continue
                        data = line[6:]
                        if data == "[DONE]":
                            return
                        try:
                            chunk = json.loads(data)
                            choices = chunk.get("choices", [])
                            if not choices:
                                continue
                            content = choices[0].get("delta", {}).get("content", "")
                            if content:
                                yield content
                        except (json.JSONDecodeError, KeyError, IndexError):
                            continue

    async def _call_with_retry(self, headers: dict, payload: dict, timeout: float | None = None) -> dict:
        """Call Anthropic API with retry logic for transient failures.

        Retries on 429, 500, 502, 503, 504 with exponential backoff.
        Raises HTTPException(503) with Retry-After header if all retries exhausted.
        """
        last_exc: Exception | None = None
        retry_after: int = 60  # Default retry-after in seconds
        request_timeout = timeout or 120.0

        for attempt in range(_MAX_RETRIES):
            try:
                async with httpx.AsyncClient(timeout=request_timeout) as client:
                    response = await client.post(
                        self.base_url, headers=headers, json=payload
                    )

                    # Check for retryable status codes
                    if response.status_code in _RETRY_STATUS_CODES:
                        retry_after = int(
                            response.headers.get("retry-after", _RETRY_DELAYS[attempt] * 10)
                        )
                        logger.warning(
                            "AI provider returned %s, attempt %s/%s, retrying in %ss",
                            response.status_code,
                            attempt + 1,
                            _MAX_RETRIES,
                            _RETRY_DELAYS[attempt],
                        )
                        if attempt < _MAX_RETRIES - 1:
                            await asyncio.sleep(_RETRY_DELAYS[attempt])
                        continue

                    response.raise_for_status()
                    result = response.json()

                    # Log token usage
                    usage = result.get("usage", {})
                    self._log_usage(
                        usage.get("input_tokens", 0),
                        usage.get("output_tokens", 0),
                    )

                    finish_reason = result.get("stop_reason")
                    if finish_reason == "max_tokens":
                        logger.warning("AI response was truncated due to max_tokens limit")

                    return result

            except httpx.TimeoutException as exc:
                last_exc = exc
                logger.warning(
                    "AI provider timeout, attempt %s/%s",
                    attempt + 1,
                    _MAX_RETRIES,
                )
                if attempt < _MAX_RETRIES - 1:
                    await asyncio.sleep(_RETRY_DELAYS[attempt])
            except httpx.ConnectError as exc:
                last_exc = exc
                logger.warning(
                    "AI provider connection error, attempt %s/%s: %s",
                    attempt + 1,
                    _MAX_RETRIES,
                    str(exc),
                )
                if attempt < _MAX_RETRIES - 1:
                    await asyncio.sleep(_RETRY_DELAYS[attempt])

        # All retries exhausted
        logger.error(
            "AI provider unavailable after %s retries: %s",
            _MAX_RETRIES,
            str(last_exc),
        )
        raise HTTPException(
            status_code=503,
            detail={
                "error": "ai_provider_unavailable",
                "message": "AI service is temporarily unavailable. Please try again later.",
                "retry_after": retry_after,
            },
            headers={"Retry-After": str(retry_after)},
        )

    async def _stream_response(
        self,
        headers: dict,
        payload: dict,
        timeout: float | None = None,
    ) -> AsyncIterator[str]:
        """Stream response from Anthropic Claude API.

        Args:
            headers: Request headers
            payload: Request payload
            timeout: Request timeout in seconds

        Yields:
            Response text chunks
        """
        request_timeout = timeout or 120.0
        async with httpx.AsyncClient(timeout=request_timeout) as client:
            async with client.stream(
                "POST",
                self.base_url,
                headers=headers,
                json=payload,
            ) as response:
                response.raise_for_status()

                total_output_tokens = 0
                buffer = ""
                chunk_count = 0

                logger.info("Starting AI stream response...")

                # Use aiter_bytes for immediate chunk delivery without buffering
                async for chunk_bytes in response.aiter_bytes():
                    buffer += chunk_bytes.decode("utf-8", errors="ignore")

                    # Process complete lines from buffer
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()

                        if not line:
                            continue

                        if line.startswith("data: "):
                            data = line[6:]
                            if data == "[DONE]":
                                logger.info("Stream complete: chunk_count=%s", chunk_count)
                                break
                            try:
                                chunk = json.loads(data)
                                # Claude uses different event types
                                event_type = chunk.get("type", "")

                                if event_type == "content_block_delta":
                                    delta = chunk.get("delta", {})
                                    content = delta.get("text", "")
                                    if content:
                                        chunk_count += 1
                                        total_output_tokens += 1
                                        if chunk_count <= 5 or chunk_count % 20 == 0:
                                            logger.debug("Yielding chunk: chunk_number=%s, content_preview=%s", chunk_count, content[:50])
                                        yield content
                                elif event_type == "message_stop":
                                    logger.info("Stream complete: chunk_count=%s", chunk_count)
                                    break
                            except json.JSONDecodeError:
                                continue

                # Log approximate usage for streaming
                self._log_usage(0, total_output_tokens)

    def _log_usage(self, input_tokens: int, output_tokens: int) -> None:
        """Log token usage for tracking."""
        usage = TokenUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            model=self.model,
            timestamp=datetime.now(UTC),
        )
        self._usage_log.append(usage)
        logger.info(
            "AI token usage: input_tokens=%s, output_tokens=%s, model=%s",
            input_tokens,
            output_tokens,
            self.model,
        )

    def get_usage_stats(self) -> dict[str, Any]:
        """Get aggregated usage statistics."""
        if not self._usage_log:
            return {"total_calls": 0, "total_input_tokens": 0, "total_output_tokens": 0}

        return {
            "total_calls": len(self._usage_log),
            "total_input_tokens": sum(u.input_tokens for u in self._usage_log),
            "total_output_tokens": sum(u.output_tokens for u in self._usage_log),
            "total_tokens": sum(u.total_tokens for u in self._usage_log),
        }

    async def generate_dm_response(
        self,
        player_message: str,
        scenario_content: dict[str, Any],
        world_state: dict[str, Any],
        players: list[dict[str, Any]],
        conversation_history: list[dict[str, str]],
    ) -> str:
        """Generate a DM response to a player action (non-streaming).

        Args:
            player_message: The player's message/action
            scenario_content: The scenario content
            world_state: Current world state
            players: List of player information
            conversation_history: Recent conversation history

        Returns:
            DM response text
        """
        system_prompt = self._build_dm_system_prompt(
            scenario_content, world_state, players
        )

        # Build messages with history (last 15 messages for context window)
        messages = conversation_history[-15:]
        messages.append({"role": "user", "content": player_message})

        result = await self._call_model(system_prompt, messages, stream=False, model=self.model_dm_response)
        return result["content"][0]["text"]

    async def stream_dm_response(
        self,
        player_message: str,
        scenario_content: dict[str, Any],
        world_state: dict[str, Any],
        players: list[dict[str, Any]],
        conversation_history: list[dict[str, str]],
    ) -> AsyncIterator[str]:
        """Generate a streaming DM response to a player action.

        Args:
            player_message: The player's message/action
            scenario_content: The scenario content
            world_state: Current world state
            players: List of player information
            conversation_history: Recent conversation history

        Yields:
            DM response text chunks
        """
        system_prompt = self._build_dm_system_prompt(
            scenario_content, world_state, players
        )

        # Build messages with history (last 6 messages to keep input tokens low for free models)
        messages = list(conversation_history[-6:])
        messages.append({"role": "user", "content": player_message})

        async for chunk in await self._call_model(system_prompt, messages, stream=True, model=self.model_dm_response):
            yield chunk

    async def generate_scenario(
        self, user_description: str
    ) -> tuple[str, dict[str, Any]]:
        """Generate a D&D scenario from user description."""
        system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
Generate a detailed, structured scenario based on the user's description.

IMPORTANT: Generate all text content (title, descriptions, dialogue, etc.) in the SAME LANGUAGE as the user's input prompt.

Return ONLY a valid JSON object with this exact structure:
{
  "title": "Scenario Title",
  "content": {
    "tone": "dark_fantasy|heroic|horror|mystery",
    "difficulty": "beginner|intermediate|hardcore",
    "players_min": 2,
    "players_max": 5,
    "world_lore": "Detailed world background and setting...",
    "acts": [
      {
        "id": "act_1",
        "name": "Начало приключения",
        "entry_condition": {
          "condition": "session_start",
          "description": "Сессия начинается"
        },
        "exit_conditions": [
          {
            "condition": "первый_квест_завершен",
            "description": "Игроки выполнили первый квест"
          }
        ],
        "scenes": [
          {
            "id": "scene_1",
            "name": "Встреча с таинственным незнакомцем",
            "mandatory": true,
            "description_for_ai": "What happens in this scene...",
            "dm_hints": ["Hint 1", "Hint 2"],
            "possible_outcomes": ["outcome1", "outcome2"]
          }
        ]
      }
    ],
    "npcs": [
      {
        "id": "npc_1",
        "name": "NPC Name",
        "role": "ally|enemy|neutral|quest_giver",
        "personality": "Personality description",
        "speech_style": "How they speak",
        "secrets": ["secret1"],
        "motivation": "Their goal"
      }
    ],
    "locations": [
      {
        "id": "loc_1",
        "name": "Location Name",
        "atmosphere": "Atmosphere description",
        "rooms": ["room1", "room2"]
      }
    ],
    "flags": [
      {
        "id": "dragon_defeated",
        "name": "Дракон побеждён",
        "description": "Игроки победили дракона"
      },
      {
        "id": "door_open",
        "name": "Дверь открыта",
        "description": "Тайная дверь была открыта"
      }
    ]
  }
}
Ensure valid JSON only."""

        user_prompt = f"Create a D&D scenario: {user_description}"

        try:
            logger.info(
                "Generating scenario with model=%s: %s",
                self.model_scenario_generation,
                user_description,
            )

            result = await self._call_model(
                system_prompt,
                [{"role": "user", "content": user_prompt}],
                stream=False,
                model=self.model_scenario_generation,
                max_tokens=self.max_tokens_scenario_generation,
                timeout=300.0,  # 5 minutes for scenario generation
            )

            logger.info("AI model response received: result_keys=%s", list(result.keys()))
            
            stop_reason = result.get("stop_reason")
            response_text = result["content"][0]["text"]
            logger.info("Response text preview: %s", response_text[:200])

            if stop_reason == "max_tokens":
                logger.error(
                    "Scenario generation truncated at max_tokens=8000. "
                    "Response length=%s chars. Increase max_tokens if this persists.",
                    len(response_text),
                )
                raise ValueError(
                    "Scenario generation was truncated (response too long). "
                    "Try a shorter/simpler scenario description."
                )

            json_text = _extract_json(response_text)
            logger.info("JSON extracted (length=%s): %s", len(json_text), json_text[:200])

            try:
                response_data = json.loads(json_text)
            except json.JSONDecodeError:
                # Try to repair common LLM JSON issues (trailing commas, etc.)
                json_text = _repair_json(json_text)
                response_data = json.loads(json_text)
            logger.info("JSON parsed successfully: keys=%s", list(response_data.keys()))

            title = response_data.get("title", "Untitled Scenario")
            content = response_data.get("content", {})

            logger.info("Scenario generated: title=%s", title)

            return title, content

        except json.JSONDecodeError as e:
            logger.error("Failed to parse AI response as JSON: %s", str(e), exc_info=True)
            raise ValueError("AI generated invalid JSON response")
        except Exception as e:
            logger.error("Failed to generate scenario: %s", str(e), exc_info=True)
            raise

    async def refine_scenario(
        self,
        current_title: str,
        current_content: dict[str, Any],
        refinement_prompt: str,
    ) -> tuple[str, dict[str, Any]]:
        """Refine an existing scenario based on user feedback."""
        system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
Refine the existing scenario based on user feedback while maintaining the same JSON structure.

IMPORTANT: Generate all text content in the SAME LANGUAGE as the user's refinement prompt.

Return ONLY a valid JSON object:
{
  "title": "Updated Title",
  "content": { ... }
}"""

        current_scenario_json = json.dumps(
            {"title": current_title, "content": current_content}, indent=2
        )

        user_prompt = f"""Current scenario:
{current_scenario_json}

Refinement request: {refinement_prompt}

Generate the updated scenario."""

        try:
            logger.info("Refining scenario with model=%s", self.model_scenario_refinement)
            result = await self._call_model(
                system_prompt,
                [{"role": "user", "content": user_prompt}],
                stream=False,
                model=self.model_scenario_refinement,
                max_tokens=self.max_tokens_scenario_refinement,
                timeout=300.0,  # 5 minutes for scenario refinement
            )

            response_text = result["content"][0]["text"]
            json_text = _extract_json(response_text)

            try:
                response_data = json.loads(json_text)
            except json.JSONDecodeError:
                json_text = _repair_json(json_text)
                response_data = json.loads(json_text)

            title = response_data.get("title", current_title)
            content = response_data.get("content", current_content)

            logger.info("Scenario refined: title=%s", title)

            return title, content

        except json.JSONDecodeError as e:
            logger.error("Failed to parse AI response as JSON: %s", str(e))
            raise ValueError("AI generated invalid JSON response")
        except Exception as e:
            logger.error("Failed to refine scenario: %s", str(e))
            raise
