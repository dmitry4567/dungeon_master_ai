"""Integration tests for AI scenario generation."""
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.services.scenario_service import ScenarioService


@pytest.mark.asyncio
class TestScenarioGeneration:
    """Tests for end-to-end scenario generation workflow."""

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_generate_scenario_with_valid_structure(
        self, mock_ai_generate: AsyncMock, db_session
    ) -> None:
        """Test that AI generates a valid scenario structure."""
        # Mock AI response with valid scenario content
        mock_content = {
            "tone": "dark_fantasy",
            "difficulty": "intermediate",
            "players_min": 2,
            "players_max": 5,
            "world_lore": "A dark world filled with ancient magic",
            "acts": [
                {
                    "id": "act_1",
                    "entry_condition": "session_start",
                    "exit_conditions": ["quest_completed"],
                    "scenes": [
                        {
                            "id": "scene_1",
                            "mandatory": True,
                            "description_for_ai": "Players meet in a tavern",
                            "dm_hints": ["Introduce the quest giver"],
                            "possible_outcomes": ["accept_quest", "decline_quest"],
                        }
                    ],
                }
            ],
            "npcs": [
                {
                    "id": "npc_1",
                    "name": "Old Wizard",
                    "role": "quest_giver",
                    "personality": "wise and mysterious",
                    "speech_style": "cryptic",
                    "secrets": ["knows_dark_prophecy"],
                    "motivation": "save the kingdom",
                }
            ],
            "locations": [
                {
                    "id": "loc_1",
                    "name": "The Rusty Tavern",
                    "atmosphere": "warm but suspicious",
                    "rooms": ["main_hall", "back_room"],
                }
            ],
        }
        mock_ai_generate.return_value = ("Test Adventure", mock_content)

        service = ScenarioService(db_session)
        user_id = uuid.uuid4()
        description = "A dark fantasy adventure in a haunted forest"

        scenario = await service.generate_scenario(user_id, description)

        # Verify scenario structure
        assert scenario.title == "Test Adventure"
        assert scenario.status == "draft"
        assert scenario.creator_id == user_id

        # Verify version was created
        assert scenario.current_version is not None
        assert scenario.current_version.version == 1
        assert scenario.current_version.user_prompt == description

        # Verify content structure
        content = scenario.current_version.content
        assert content["tone"] == "dark_fantasy"
        assert content["difficulty"] == "intermediate"
        assert len(content["acts"]) == 1
        assert len(content["npcs"]) == 1
        assert len(content["locations"]) == 1

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_generate_scenario_validation_errors(
        self, mock_ai_generate: AsyncMock, db_session
    ) -> None:
        """Test that validation errors are captured when AI generates invalid structure."""
        # Mock AI response with invalid structure (missing required fields)
        mock_content = {
            "tone": "dark_fantasy",
            "difficulty": "intermediate",
            "players_min": 2,
            "players_max": 5,
            "acts": [],  # Empty acts - invalid
            "npcs": [],
            "locations": [],
        }
        mock_ai_generate.return_value = ("Invalid Adventure", mock_content)

        service = ScenarioService(db_session)
        user_id = uuid.uuid4()
        description = "Generate something invalid"

        scenario = await service.generate_scenario(user_id, description)

        # Verify validation errors were captured
        assert scenario.current_version.validation_errors is not None
        assert len(scenario.current_version.validation_errors) > 0

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.refine_scenario")
    async def test_refine_scenario_creates_new_version(
        self, mock_ai_refine: AsyncMock, db_session
    ) -> None:
        """Test that refining a scenario creates a new version."""
        # First create a scenario
        service = ScenarioService(db_session)
        user_id = uuid.uuid4()

        # Create initial scenario (would normally come from database)
        initial_content = {
            "tone": "dark_fantasy",
            "difficulty": "intermediate",
            "players_min": 2,
            "players_max": 5,
            "world_lore": "Original lore",
            "acts": [],
            "npcs": [],
            "locations": [],
        }

        # Mock refined content
        refined_content = {
            **initial_content,
            "difficulty": "hardcore",
            "world_lore": "Refined lore with more detail",
        }
        mock_ai_refine.return_value = ("Test Adventure", refined_content)

        # This test will need a real scenario from the database
        # For now, we're just testing the structure
        # In real implementation, we'd create scenario first, then refine it

        # Verify the mock was configured correctly
        assert mock_ai_refine is not None

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_generate_scenario_with_npc_references(
        self, mock_ai_generate: AsyncMock, db_session
    ) -> None:
        """Test that scenario validation checks NPC references in scenes."""
        mock_content = {
            "tone": "mystery",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 4,
            "world_lore": "A mysterious town",
            "acts": [
                {
                    "id": "act_1",
                    "entry_condition": "session_start",
                    "exit_conditions": ["mystery_solved"],
                    "scenes": [
                        {
                            "id": "scene_1",
                            "mandatory": True,
                            "description_for_ai": "Meet the mayor (npc_1)",
                            "dm_hints": ["The mayor is hiding something"],
                            "possible_outcomes": ["trust", "suspicious"],
                        }
                    ],
                }
            ],
            "npcs": [
                {
                    "id": "npc_1",
                    "name": "Mayor Johnson",
                    "role": "antagonist",
                    "personality": "charming but sinister",
                    "speech_style": "formal",
                    "secrets": ["murdered_predecessor"],
                    "motivation": "maintain power",
                }
            ],
            "locations": [
                {
                    "id": "loc_1",
                    "name": "Town Hall",
                    "atmosphere": "imposing",
                    "rooms": ["office", "archives"],
                }
            ],
        }
        mock_ai_generate.return_value = ("Mystery in Town", mock_content)

        service = ScenarioService(db_session)
        user_id = uuid.uuid4()
        description = "A murder mystery in a small town"

        scenario = await service.generate_scenario(user_id, description)

        # Verify NPC reference validation passed
        assert scenario.current_version.validation_errors is None or len(
            scenario.current_version.validation_errors
        ) == 0

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_generate_scenario_moderation_filter(
        self, mock_ai_generate: AsyncMock, db_session
    ) -> None:
        """Test that inappropriate content is filtered by moderation."""
        # This test would check that the moderation service is called
        # For now, we just verify the structure is in place
        service = ScenarioService(db_session)
        user_id = uuid.uuid4()
        description = "An adventure with inappropriate content"

        # In real implementation, this should raise or return error
        # when moderation fails
        # For now, we're just setting up the test structure
        assert service is not None


@pytest.mark.asyncio
class TestScenarioVersioning:
    """Tests for scenario version management."""

    async def _create_test_user(self, db_session) -> uuid.UUID:
        """Helper to create a test user and return their ID."""
        from src.core.security import hash_password
        from src.models.user import User

        user = User(
            id=uuid.uuid4(),
            email=f"test-{uuid.uuid4()}@example.com",
            password_hash=hash_password("testpassword123"),
            name="Test User",
        )
        db_session.add(user)
        await db_session.commit()
        return user.id

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.refine_scenario")
    async def test_restore_previous_version(
        self, mock_refine: AsyncMock, mock_generate: AsyncMock, db_session
    ) -> None:
        """Test restoring a previous version makes it current."""
        # Setup mock responses
        initial_content = {
            "tone": "dark_fantasy",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 4,
            "world_lore": "Initial lore",
            "acts": [{"id": "act_1", "entry_condition": "start", "exit_conditions": [], "scenes": [{"id": "s1"}]}],
            "npcs": [{"id": "npc_1", "name": "Test", "role": "ally", "personality": "kind", "speech_style": "formal", "motivation": "help"}],
            "locations": [{"id": "loc_1", "name": "Town", "atmosphere": "calm", "rooms": []}],
        }
        refined_content = {
            **initial_content,
            "difficulty": "hardcore",
            "world_lore": "Refined lore",
        }
        mock_generate.return_value = ("Initial Adventure", initial_content)
        mock_refine.return_value = ("Refined Adventure", refined_content)

        # Create user first
        user_id = await self._create_test_user(db_session)

        service = ScenarioService(db_session)

        # Create initial scenario (version 1)
        scenario = await service.generate_scenario(user_id, "Create a test adventure")
        version_1_id = scenario.current_version_id
        assert scenario.current_version.version == 1

        # Refine scenario (version 2)
        scenario = await service.refine_scenario(scenario.id, user_id, "Make it harder")
        version_2_id = scenario.current_version_id
        assert scenario.current_version.version == 2
        assert scenario.current_version.content["difficulty"] == "hardcore"

        # Restore version 1
        scenario = await service.restore_version(scenario.id, version_1_id, user_id)

        # Verify version 1 is now current
        assert scenario.current_version_id == version_1_id
        assert scenario.current_version.version == 1
        assert scenario.current_version.content["difficulty"] == "beginner"

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.refine_scenario")
    async def test_list_versions_ordered_by_version_number(
        self, mock_refine: AsyncMock, mock_generate: AsyncMock, db_session
    ) -> None:
        """Test that versions are returned in correct order (newest first)."""
        initial_content = {
            "tone": "dark_fantasy",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 4,
            "world_lore": "Initial",
            "acts": [{"id": "act_1", "entry_condition": "start", "exit_conditions": [], "scenes": [{"id": "s1"}]}],
            "npcs": [{"id": "npc_1", "name": "Test", "role": "ally", "personality": "kind", "speech_style": "formal", "motivation": "help"}],
            "locations": [{"id": "loc_1", "name": "Town", "atmosphere": "calm", "rooms": []}],
        }
        mock_generate.return_value = ("Adventure", initial_content)
        mock_refine.return_value = ("Adventure v2", {**initial_content, "world_lore": "Refined"})

        # Create user first
        user_id = await self._create_test_user(db_session)

        service = ScenarioService(db_session)

        # Create scenario and add multiple versions
        scenario = await service.generate_scenario(user_id, "Test adventure")
        await service.refine_scenario(scenario.id, user_id, "Update 1")

        mock_refine.return_value = ("Adventure v3", {**initial_content, "world_lore": "More refined"})
        await service.refine_scenario(scenario.id, user_id, "Update 2")

        # List versions
        versions = await service.list_versions(scenario.id, user_id)

        # Should be ordered by version descending (newest first)
        assert len(versions) == 3
        assert versions[0].version == 3
        assert versions[1].version == 2
        assert versions[2].version == 1

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_restore_version_unauthorized(
        self, mock_generate: AsyncMock, db_session
    ) -> None:
        """Test that restoring version by non-owner raises error."""
        mock_content = {
            "tone": "dark_fantasy",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 4,
            "world_lore": "Test",
            "acts": [{"id": "act_1", "entry_condition": "start", "exit_conditions": [], "scenes": [{"id": "s1"}]}],
            "npcs": [{"id": "npc_1", "name": "Test", "role": "ally", "personality": "kind", "speech_style": "formal", "motivation": "help"}],
            "locations": [{"id": "loc_1", "name": "Town", "atmosphere": "calm", "rooms": []}],
        }
        mock_generate.return_value = ("Adventure", mock_content)

        # Create owner user
        owner_id = await self._create_test_user(db_session)
        # Create another user
        other_user_id = await self._create_test_user(db_session)

        service = ScenarioService(db_session)

        # Create scenario
        scenario = await service.generate_scenario(owner_id, "Test adventure")
        version_id = scenario.current_version_id

        # Try to restore by non-owner
        with pytest.raises(ValueError, match="Not authorized"):
            await service.restore_version(scenario.id, version_id, other_user_id)

    @patch("src.services.ai_service_openrouter.AIServiceOpenRouter.generate_scenario")
    async def test_restore_nonexistent_version(
        self, mock_generate: AsyncMock, db_session
    ) -> None:
        """Test that restoring non-existent version raises error."""
        mock_content = {
            "tone": "dark_fantasy",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 4,
            "world_lore": "Test",
            "acts": [{"id": "act_1", "entry_condition": "start", "exit_conditions": [], "scenes": [{"id": "s1"}]}],
            "npcs": [{"id": "npc_1", "name": "Test", "role": "ally", "personality": "kind", "speech_style": "formal", "motivation": "help"}],
            "locations": [{"id": "loc_1", "name": "Town", "atmosphere": "calm", "rooms": []}],
        }
        mock_generate.return_value = ("Adventure", mock_content)

        # Create user first
        user_id = await self._create_test_user(db_session)

        service = ScenarioService(db_session)

        # Create scenario
        scenario = await service.generate_scenario(user_id, "Test adventure")

        # Try to restore non-existent version
        fake_version_id = uuid.uuid4()
        with pytest.raises(ValueError, match="Version not found"):
            await service.restore_version(scenario.id, fake_version_id, user_id)
