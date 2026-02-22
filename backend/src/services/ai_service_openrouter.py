"""AI service for OpenRouter API integration."""
import json
import logging
from typing import Any

import httpx

from src.core.config import get_settings

logger = logging.getLogger(__name__)


class AIServiceOpenRouter:
    """Service for AI generation using OpenRouter."""

    def __init__(self) -> None:
        """Initialize AI service with OpenRouter client."""
        settings = get_settings()
        self.api_key = settings.OPENROUTER_API_KEY
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"
        self.model = "openrouter/free"
        self.max_tokens = 4096

    async def _call_model(self, system_prompt: str, user_prompt: str) -> dict:
        """Internal helper to call OpenRouter."""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": self.max_tokens,
            "temperature": 0.7,
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(self.base_url, headers=headers, json=payload)
            print(response.status_code)
            print(response.text)
            response.raise_for_status()
            return response.json()

    async def generate_scenario(
        self, user_description: str
    ) -> tuple[str, dict[str, Any]]:
        """
        Generate a D&D scenario from user description.
        """

        system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
Generate a detailed, structured scenario based on the user's description.

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
        "entry_condition": "session_start",
        "exit_conditions": ["flag_name"],
        "scenes": [
          {
            "id": "scene_1",
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
Ensure valid JSON only.
"""

        user_prompt = f"Create a D&D scenario: {user_description}"

        try:
            result = await self._call_model(system_prompt, user_prompt)

            response_text = result["choices"][0]["message"]["content"]
            response_data = json.loads(response_text)

            title = response_data.get("title", "Untitled Scenario")
            content = response_data.get("content", {})

            logger.info(
                f"Generated scenario: {title}",
                extra={
                    "input_tokens": result.get("usage", {}).get("prompt_tokens"),
                    "output_tokens": result.get("usage", {}).get("completion_tokens"),
                },
            )

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
        """
        Refine an existing scenario based on user feedback.
        """

        system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
Refine the existing scenario based on user feedback while maintaining the same JSON structure.

Return ONLY a valid JSON object:
{
  "title": "Updated Title",
  "content": { ... }
}
"""

        current_scenario_json = json.dumps(
            {"title": current_title, "content": current_content}, indent=2
        )

        user_prompt = f"""Current scenario:
{current_scenario_json}

Refinement request: {refinement_prompt}

Generate the updated scenario."""

        try:
            result = await self._call_model(system_prompt, user_prompt)

            response_text = result["choices"][0]["message"]["content"]
            response_data = json.loads(response_text)

            title = response_data.get("title", current_title)
            content = response_data.get("content", current_content)

            logger.info(
                f"Refined scenario: {title}",
                extra={
                    "input_tokens": result.get("usage", {}).get("prompt_tokens"),
                    "output_tokens": result.get("usage", {}).get("completion_tokens"),
                },
            )

            return title, content

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            raise ValueError("AI generated invalid JSON response")
        except Exception as e:
            logger.error(f"Failed to refine scenario: {e}")
            raise