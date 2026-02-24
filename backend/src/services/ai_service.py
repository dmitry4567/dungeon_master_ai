"""AI service for OpenRouter API integration with streaming support."""
import json
import logging
import re
from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import UTC, datetime
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
    """Service for AI generation using OpenRouter with streaming support."""

    def __init__(self) -> None:
        """Initialize AI service with OpenRouter client."""
        settings = get_settings()
        self.api_key = settings.OPENROUTER_API_KEY
        self.model = settings.OPENROUTER_MODEL
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"
        self.max_tokens = 8192
        self._usage_log: list[TokenUsage] = []
        logger.info(f"Using OpenRouter with model: {self.model}")

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

        # Build NPC reference
        npcs_section = []
        for npc in scenario_content.get("npcs", []):
            npcs_section.append(
                f"- {npc.get('name')}: {npc.get('role')} - {npc.get('personality')} "
                f"(speaks: {npc.get('speech_style', 'normally')})"
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

        return f"""You are an expert Dungeon Master for a D&D 5e game session.

CRITICAL INSTRUCTION: You MUST respond in the SAME LANGUAGE as the player's message. If they write in Russian, respond in Russian. If they write in English, respond in English. Match their language exactly.

## Scenario: {scenario_content.get("title", "Adventure")}
Tone: {scenario_content.get("tone", "heroic")}
Difficulty: {scenario_content.get("difficulty", "intermediate")}

## World Lore
{scenario_content.get("world_lore", "A mysterious world awaits...")}

## Current Location
{location_info}

## Current Scene
{current_scene_info}

## NPCs
{npcs_text}

## Players
{players_section}

## World State
- Current Act: {world_state.get("current_act", "act_1")}
- Completed Scenes: {", ".join(world_state.get("completed_scenes", [])) or "None"}
- Active Flags: {json.dumps(world_state.get("flags", {}))}
- Combat Active: {world_state.get("combat_active", False)}

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

    async def _call_model(
        self,
        system_prompt: str,
        messages: list[dict[str, str]],
        stream: bool = False,
    ) -> dict | AsyncIterator[str]:
        """Internal helper to call OpenRouter.

        Args:
            system_prompt: System prompt for the model
            messages: List of conversation messages
            stream: Whether to stream the response

        Returns:
            Response dict or async iterator of chunks
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                *messages,
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.8,
            "stream": stream,
        }

        if stream:
            return self._stream_response(headers, payload)
        else:
            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    self.base_url, headers=headers, json=payload
                )
                response.raise_for_status()
                result = response.json()

                # Log token usage
                usage = result.get("usage", {})
                self._log_usage(
                    usage.get("prompt_tokens", 0),
                    usage.get("completion_tokens", 0),
                )

                finish_reason = result.get("choices", [{}])[0].get("finish_reason")
                if finish_reason == "length":
                    logger.warning("AI response was truncated due to max_tokens limit")

                return result

    async def _stream_response(
        self,
        headers: dict,
        payload: dict,
    ) -> AsyncIterator[str]:
        """Stream response from OpenRouter.

        Args:
            headers: Request headers
            payload: Request payload

        Yields:
            Response text chunks
        """
        async with httpx.AsyncClient(timeout=120.0) as client:
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
                                logger.info(f"Stream complete. Total chunks: {chunk_count}")
                                break
                            try:
                                chunk = json.loads(data)
                                delta = chunk.get("choices", [{}])[0].get("delta", {})
                                content = delta.get("content", "")
                                if content:
                                    chunk_count += 1
                                    total_output_tokens += 1
                                    if chunk_count <= 5 or chunk_count % 20 == 0:
                                        logger.debug(f"Yielding chunk #{chunk_count}: {repr(content[:50])}")
                                    yield content
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
            f"AI usage: {input_tokens} input, {output_tokens} output tokens",
            extra={
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "model": self.model,
            },
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

        result = await self._call_model(system_prompt, messages, stream=False)
        return result["choices"][0]["message"]["content"]

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

        # Build messages with history (last 15 messages for context window)
        messages = conversation_history[-15:]
        messages.append({"role": "user", "content": player_message})

        async for chunk in await self._call_model(system_prompt, messages, stream=True):
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
    ]
  }
}
Ensure valid JSON only."""

        user_prompt = f"Create a D&D scenario: {user_description}"

        try:
            result = await self._call_model(
                system_prompt,
                [{"role": "user", "content": user_prompt}],
                stream=False,
            )

            response_text = result["choices"][0]["message"]["content"]
            json_text = _extract_json(response_text)
            response_data = json.loads(json_text)

            title = response_data.get("title", "Untitled Scenario")
            content = response_data.get("content", {})

            logger.info(f"Generated scenario: {title}")

            return title, content

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            raise ValueError("AI generated invalid JSON response")
        except Exception as e:
            logger.error(f"Failed to generate scenario: {e}")
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
            result = await self._call_model(
                system_prompt,
                [{"role": "user", "content": user_prompt}],
                stream=False,
            )

            response_text = result["choices"][0]["message"]["content"]
            json_text = _extract_json(response_text)
            response_data = json.loads(json_text)

            title = response_data.get("title", current_title)
            content = response_data.get("content", current_content)

            logger.info(f"Refined scenario: {title}")

            return title, content

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            raise ValueError("AI generated invalid JSON response")
        except Exception as e:
            logger.error(f"Failed to refine scenario: {e}")
            raise
