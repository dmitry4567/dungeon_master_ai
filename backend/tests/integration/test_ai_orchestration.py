"""Integration tests for AI orchestration."""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from src.services.ai_service import AIService


class TestAIServiceIntegration:
    """Integration tests for AIService."""

    @pytest.fixture
    def ai_service(self):
        """Create AIService instance."""
        return AIService()

    @pytest.fixture
    def scenario_content(self):
        """Sample scenario content."""
        return {
            "title": "Test Adventure",
            "tone": "heroic",
            "difficulty": "intermediate",
            "world_lore": "A land of magic and wonder.",
            "acts": [
                {
                    "id": "act_1",
                    "entry_condition": "session_start",
                    "scenes": [
                        {
                            "id": "scene_1",
                            "description_for_ai": "The party arrives at the tavern.",
                        }
                    ],
                }
            ],
            "npcs": [
                {
                    "id": "npc_1",
                    "name": "Barkeep Bob",
                    "role": "quest_giver",
                    "personality": "Friendly but wary",
                    "speech_style": "Gruff but warm",
                }
            ],
            "locations": [
                {
                    "id": "loc_1",
                    "name": "The Rusty Dragon",
                    "atmosphere": "Warm and inviting",
                }
            ],
        }

    @pytest.fixture
    def world_state(self):
        """Sample world state."""
        return {
            "current_act": "act_1",
            "current_scene": None,
            "current_location": "loc_1",
            "completed_scenes": [],
            "flags": {},
            "combat_active": False,
            "turn_order": [],
        }

    @pytest.fixture
    def players(self):
        """Sample players list."""
        return [
            {
                "id": "user-1",
                "name": "Test Player",
                "character": {
                    "name": "Thorin",
                    "class": "fighter",
                    "race": "dwarf",
                    "level": 1,
                },
            }
        ]

    def test_build_dm_system_prompt(
        self, ai_service, scenario_content, world_state, players
    ):
        """Test that system prompt is built correctly."""
        prompt = ai_service._build_dm_system_prompt(
            scenario_content, world_state, players
        )

        # Check key elements are present
        assert "Dungeon Master" in prompt
        assert "Test Adventure" in prompt
        assert "heroic" in prompt
        assert "Barkeep Bob" in prompt
        assert "The Rusty Dragon" in prompt
        assert "Thorin" in prompt
        assert "dwarf" in prompt
        assert "fighter" in prompt
        assert "SAME LANGUAGE" in prompt  # Language matching instruction

    def test_build_dm_system_prompt_empty_players(
        self, ai_service, scenario_content, world_state
    ):
        """Test prompt building with no players."""
        prompt = ai_service._build_dm_system_prompt(
            scenario_content, world_state, []
        )

        assert "No players" in prompt

    def test_build_dm_system_prompt_unknown_location(
        self, ai_service, scenario_content, players
    ):
        """Test prompt building with unknown location."""
        world_state = {
            "current_act": "act_1",
            "current_location": "unknown_loc",
            "completed_scenes": [],
            "flags": {},
        }
        prompt = ai_service._build_dm_system_prompt(
            scenario_content, world_state, players
        )

        assert "Unknown" in prompt

    @pytest.mark.asyncio
    async def test_generate_dm_response_mocked(
        self, ai_service, scenario_content, world_state, players
    ):
        """Test DM response generation with mocked API."""
        mock_response = {
            "choices": [
                {
                    "message": {
                        "content": "Welcome, brave adventurer! The tavern is warm and inviting."
                    },
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 100, "completion_tokens": 50},
        }

        with patch.object(
            ai_service, "_call_model", new_callable=AsyncMock
        ) as mock_call:
            mock_call.return_value = mock_response

            response = await ai_service.generate_dm_response(
                player_message="I enter the tavern",
                scenario_content=scenario_content,
                world_state=world_state,
                players=players,
                conversation_history=[],
            )

            assert "Welcome" in response or "tavern" in response.lower()
            mock_call.assert_called_once()

    @pytest.mark.asyncio
    async def test_stream_dm_response_mocked(
        self, ai_service, scenario_content, world_state, players
    ):
        """Test streaming DM response with mocked API."""

        async def mock_stream():
            chunks = ["Welcome", ", brave", " adventurer!"]
            for chunk in chunks:
                yield chunk

        with patch.object(
            ai_service, "_call_model", new_callable=AsyncMock
        ) as mock_call:
            mock_call.return_value = mock_stream()

            full_response = ""
            async for chunk in ai_service.stream_dm_response(
                player_message="I enter the tavern",
                scenario_content=scenario_content,
                world_state=world_state,
                players=players,
                conversation_history=[],
            ):
                full_response += chunk

            assert full_response == "Welcome, brave adventurer!"

    def test_usage_stats_empty(self, ai_service):
        """Test usage stats when no calls made."""
        stats = ai_service.get_usage_stats()

        assert stats["total_calls"] == 0
        assert stats["total_input_tokens"] == 0
        assert stats["total_output_tokens"] == 0

    def test_log_usage(self, ai_service):
        """Test usage logging."""
        ai_service._log_usage(100, 50)
        ai_service._log_usage(200, 100)

        stats = ai_service.get_usage_stats()

        assert stats["total_calls"] == 2
        assert stats["total_input_tokens"] == 300
        assert stats["total_output_tokens"] == 150
        assert stats["total_tokens"] == 450


class TestAIServiceScenarioGeneration:
    """Tests for scenario generation."""

    @pytest.fixture
    def ai_service(self):
        return AIService()

    @pytest.mark.asyncio
    async def test_generate_scenario_mocked(self, ai_service):
        """Test scenario generation with mocked API."""
        mock_response = {
            "choices": [
                {
                    "message": {
                        "content": """{
                            "title": "The Lost Mine",
                            "content": {
                                "tone": "dark_fantasy",
                                "difficulty": "intermediate",
                                "world_lore": "An abandoned mine...",
                                "acts": [],
                                "npcs": [],
                                "locations": []
                            }
                        }"""
                    },
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 100, "completion_tokens": 200},
        }

        with patch.object(
            ai_service, "_call_model", new_callable=AsyncMock
        ) as mock_call:
            mock_call.return_value = mock_response

            title, content = await ai_service.generate_scenario(
                "Create a dungeon adventure in an abandoned mine"
            )

            assert title == "The Lost Mine"
            assert content["tone"] == "dark_fantasy"

    @pytest.mark.asyncio
    async def test_generate_scenario_invalid_json(self, ai_service):
        """Test scenario generation with invalid JSON response."""
        mock_response = {
            "choices": [
                {
                    "message": {"content": "This is not valid JSON"},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 100, "completion_tokens": 50},
        }

        with patch.object(
            ai_service, "_call_model", new_callable=AsyncMock
        ) as mock_call:
            mock_call.return_value = mock_response

            with pytest.raises(ValueError, match="invalid JSON"):
                await ai_service.generate_scenario("Create a scenario")
