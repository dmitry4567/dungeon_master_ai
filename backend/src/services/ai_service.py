# """AI service for Claude API integration."""
# import json
# import logging
# from typing import Any

# from anthropic import Anthropic
# from anthropic.types import Message

# from src.core.config import get_settings

# logger = logging.getLogger(__name__)


# class AIService:
#     """Service for AI generation using Claude."""

#     def __init__(self) -> None:
#         """Initialize AI service with Anthropic client."""
#         settings = get_settings()
#         self.client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
#         self.model = "claude-3-5-sonnet-20241022"  # Sonnet for scenario generation
#         self.max_tokens = 4096

#     async def generate_scenario(
#         self, user_description: str
#     ) -> tuple[str, dict[str, Any]]:
#         """
#         Generate a D&D scenario from user description.

#         Args:
#             user_description: Natural language description of desired scenario

#         Returns:
#             Tuple of (scenario_title, scenario_content)
#         """
#         system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
# Generate a detailed, structured scenario based on the user's description.

# Return ONLY a valid JSON object with this exact structure:
# {
#   "title": "Scenario Title",
#   "content": {
#     "tone": "dark_fantasy|heroic|horror|mystery",
#     "difficulty": "beginner|intermediate|hardcore",
#     "players_min": 2,
#     "players_max": 5,
#     "world_lore": "Detailed world background and setting...",
#     "acts": [
#       {
#         "id": "act_1",
#         "entry_condition": "session_start",
#         "exit_conditions": ["flag_name"],
#         "scenes": [
#           {
#             "id": "scene_1",
#             "mandatory": true,
#             "description_for_ai": "What happens in this scene...",
#             "dm_hints": ["Hint 1", "Hint 2"],
#             "possible_outcomes": ["outcome1", "outcome2"]
#           }
#         ]
#       }
#     ],
#     "npcs": [
#       {
#         "id": "npc_1",
#         "name": "NPC Name",
#         "role": "ally|enemy|neutral|quest_giver",
#         "personality": "Personality description",
#         "speech_style": "How they speak",
#         "secrets": ["secret1"],
#         "motivation": "Their goal"
#       }
#     ],
#     "locations": [
#       {
#         "id": "loc_1",
#         "name": "Location Name",
#         "atmosphere": "Atmosphere description",
#         "rooms": ["room1", "room2"]
#       }
#     ]
#   }
# }

# Ensure:
# - At least 1 act with 1+ scenes
# - At least 1 NPC and 1 location
# - All IDs are unique and lowercase with underscores
# - Content is appropriate for all audiences (no graphic violence/sexual content)
# - Scenarios follow D&D 5e rules and conventions
# """

#         user_prompt = f"Create a D&D scenario: {user_description}"

#         try:
#             message: Message = self.client.messages.create(
#                 model=self.model,
#                 max_tokens=self.max_tokens,
#                 system=system_prompt,
#                 messages=[{"role": "user", "content": user_prompt}],
#             )

#             # Extract response text
#             response_text = message.content[0].text

#             # Parse JSON response
#             response_data = json.loads(response_text)
#             title = response_data.get("title", "Untitled Scenario")
#             content = response_data.get("content", {})

#             logger.info(
#                 f"Generated scenario: {title}",
#                 extra={
#                     "input_tokens": message.usage.input_tokens,
#                     "output_tokens": message.usage.output_tokens,
#                 },
#             )

#             return title, content

#         except json.JSONDecodeError as e:
#             logger.error(f"Failed to parse AI response as JSON: {e}")
#             raise ValueError("AI generated invalid JSON response")
#         except Exception as e:
#             logger.error(f"Failed to generate scenario: {e}")
#             raise

#     async def refine_scenario(
#         self,
#         current_title: str,
#         current_content: dict[str, Any],
#         refinement_prompt: str,
#     ) -> tuple[str, dict[str, Any]]:
#         """
#         Refine an existing scenario based on user feedback.

#         Args:
#             current_title: Current scenario title
#             current_content: Current scenario content
#             refinement_prompt: User's refinement instructions

#         Returns:
#             Tuple of (new_title, new_content)
#         """
#         system_prompt = """You are an expert D&D 5e Dungeon Master and scenario designer.
# Refine the existing scenario based on user feedback while maintaining the same JSON structure.

# Return ONLY a valid JSON object with the same structure as before:
# {
#   "title": "Updated Title",
#   "content": { ... }
# }

# Preserve elements that weren't mentioned in the refinement prompt.
# Ensure all changes are appropriate and follow D&D 5e conventions.
# """

#         current_scenario_json = json.dumps(
#             {"title": current_title, "content": current_content}, indent=2
#         )

#         user_prompt = f"""Current scenario:
# {current_scenario_json}

# Refinement request: {refinement_prompt}

# Generate the updated scenario."""

#         try:
#             message: Message = self.client.messages.create(
#                 model=self.model,
#                 max_tokens=self.max_tokens,
#                 system=system_prompt,
#                 messages=[{"role": "user", "content": user_prompt}],
#             )

#             response_text = message.content[0].text
#             response_data = json.loads(response_text)
#             title = response_data.get("title", current_title)
#             content = response_data.get("content", current_content)

#             logger.info(
#                 f"Refined scenario: {title}",
#                 extra={
#                     "input_tokens": message.usage.input_tokens,
#                     "output_tokens": message.usage.output_tokens,
#                 },
#             )

#             return title, content

#         except json.JSONDecodeError as e:
#             logger.error(f"Failed to parse AI response as JSON: {e}")
#             raise ValueError("AI generated invalid JSON response")
#         except Exception as e:
#             logger.error(f"Failed to refine scenario: {e}")
#             raise
