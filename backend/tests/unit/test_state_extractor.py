"""Unit tests for state extractor."""
import pytest

from src.services.state_extractor import StateExtractor, StateUpdate


class TestStateUpdate:
    """Tests for StateUpdate dataclass."""

    def test_to_dict(self):
        """Test converting StateUpdate to dict."""
        update = StateUpdate(
            events_occurred=["door_opened", "npc_met"],
            location_changed="tavern",
            scene_completed="intro_scene",
            flags_changed={"met_barkeep": True},
        )
        data = update.to_dict()

        assert data["events_occurred"] == ["door_opened", "npc_met"]
        assert data["location_changed"] == "tavern"
        assert data["scene_completed"] == "intro_scene"
        assert data["flags_changed"] == {"met_barkeep": True}

    def test_has_changes_with_events(self):
        """Test has_changes when events occurred."""
        update = StateUpdate(
            events_occurred=["combat_started"],
            location_changed=None,
            scene_completed=None,
            flags_changed={},
        )
        assert update.has_changes() is True

    def test_has_changes_with_location(self):
        """Test has_changes when location changed."""
        update = StateUpdate(
            events_occurred=[],
            location_changed="forest",
            scene_completed=None,
            flags_changed={},
        )
        assert update.has_changes() is True

    def test_has_changes_with_scene(self):
        """Test has_changes when scene completed."""
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed="boss_fight",
            flags_changed={},
        )
        assert update.has_changes() is True

    def test_has_changes_with_flags(self):
        """Test has_changes when flags changed."""
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed=None,
            flags_changed={"quest_accepted": True},
        )
        assert update.has_changes() is True

    def test_has_changes_empty(self):
        """Test has_changes when nothing changed."""
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed=None,
            flags_changed={},
        )
        assert update.has_changes() is False


class TestStateExtractor:
    """Tests for StateExtractor class."""

    def setup_method(self):
        self.extractor = StateExtractor()

    def test_build_context(self):
        """Test building context for state extraction."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": ["intro"],
            "flags": {"met_barkeep": True},
        }
        scenario_content = {
            "locations": [
                {"id": "tavern", "name": "The Rusty Dragon"},
                {"id": "forest", "name": "Dark Forest"},
            ],
            "acts": [
                {
                    "id": "act_1",
                    "scenes": [
                        {"id": "intro"},
                        {"id": "quest_start"},
                    ],
                }
            ],
        }

        context = self.extractor._build_context(world_state, scenario_content)

        assert "Current Act: act_1" in context
        assert "Current Location: tavern" in context
        assert "tavern" in context
        assert "forest" in context
        assert "intro" in context
        assert "quest_start" in context

    def test_apply_state_update_location(self):
        """Test applying location change."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": [],
            "flags": {},
        }
        update = StateUpdate(
            events_occurred=[],
            location_changed="forest",
            scene_completed=None,
            flags_changed={},
        )

        new_state = self.extractor.apply_state_update(world_state, update)

        assert new_state["current_location"] == "forest"
        # Original should be unchanged
        assert world_state["current_location"] == "tavern"

    def test_apply_state_update_scene_completed(self):
        """Test applying scene completion."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": ["intro"],
            "flags": {},
        }
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed="quest_start",
            flags_changed={},
        )

        new_state = self.extractor.apply_state_update(world_state, update)

        assert "quest_start" in new_state["completed_scenes"]
        assert "intro" in new_state["completed_scenes"]

    def test_apply_state_update_no_duplicate_scenes(self):
        """Test that completing same scene twice doesn't duplicate."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": ["intro"],
            "flags": {},
        }
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed="intro",  # Already completed
            flags_changed={},
        )

        new_state = self.extractor.apply_state_update(world_state, update)

        assert new_state["completed_scenes"].count("intro") == 1

    def test_apply_state_update_flags(self):
        """Test applying flag changes."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": [],
            "flags": {"met_barkeep": True},
        }
        update = StateUpdate(
            events_occurred=[],
            location_changed=None,
            scene_completed=None,
            flags_changed={"quest_accepted": True, "met_barkeep": False},
        )

        new_state = self.extractor.apply_state_update(world_state, update)

        assert new_state["flags"]["quest_accepted"] is True
        assert new_state["flags"]["met_barkeep"] is False

    def test_apply_state_update_multiple_changes(self):
        """Test applying multiple changes at once."""
        world_state = {
            "current_act": "act_1",
            "current_location": "tavern",
            "completed_scenes": [],
            "flags": {},
        }
        update = StateUpdate(
            events_occurred=["combat_ended"],
            location_changed="forest",
            scene_completed="tavern_brawl",
            flags_changed={"brawl_won": True},
        )

        new_state = self.extractor.apply_state_update(world_state, update)

        assert new_state["current_location"] == "forest"
        assert "tavern_brawl" in new_state["completed_scenes"]
        assert new_state["flags"]["brawl_won"] is True
