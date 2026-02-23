"""Unit tests for D&D 5e validation."""
import pytest

from src.services.dnd_validator import (
    VALID_CLASSES,
    VALID_RACES,
    DnDValidationResult,
    is_valid_class,
    is_valid_race,
    validate_ability_scores,
    validate_backstory,
    validate_character,
    validate_class,
    validate_level,
    validate_name,
    validate_race,
)


class TestValidateClass:
    """Tests for class validation."""

    @pytest.mark.parametrize("character_class", list(VALID_CLASSES))
    def test_valid_classes(self, character_class: str) -> None:
        """Test all valid D&D 5e classes."""
        result = DnDValidationResult()
        validate_class(character_class, result)
        assert result.is_valid

    @pytest.mark.parametrize("character_class", ["Fighter", "WIZARD", "Bard"])
    def test_case_insensitive(self, character_class: str) -> None:
        """Test class validation is case insensitive."""
        result = DnDValidationResult()
        validate_class(character_class, result)
        assert result.is_valid

    def test_invalid_class(self) -> None:
        """Test invalid class returns error."""
        result = DnDValidationResult()
        validate_class("necromancer", result)
        assert not result.is_valid
        assert len(result.errors) == 1
        assert result.errors[0].field == "class"
        assert "Invalid class" in result.errors[0].message

    def test_empty_class(self) -> None:
        """Test empty class returns error."""
        result = DnDValidationResult()
        validate_class("", result)
        assert not result.is_valid
        assert result.errors[0].field == "class"


class TestValidateRace:
    """Tests for race validation."""

    @pytest.mark.parametrize("race", list(VALID_RACES))
    def test_valid_races(self, race: str) -> None:
        """Test all valid D&D 5e races."""
        result = DnDValidationResult()
        validate_race(race, result)
        assert result.is_valid

    @pytest.mark.parametrize("race", ["Human", "ELF", "Half-Elf"])
    def test_case_insensitive(self, race: str) -> None:
        """Test race validation is case insensitive."""
        result = DnDValidationResult()
        validate_race(race, result)
        assert result.is_valid

    def test_invalid_race(self) -> None:
        """Test invalid race returns error."""
        result = DnDValidationResult()
        validate_race("orc", result)
        assert not result.is_valid
        assert len(result.errors) == 1
        assert result.errors[0].field == "race"
        assert "Invalid race" in result.errors[0].message

    def test_empty_race(self) -> None:
        """Test empty race returns error."""
        result = DnDValidationResult()
        validate_race("", result)
        assert not result.is_valid


class TestValidateLevel:
    """Tests for level validation."""

    @pytest.mark.parametrize("level", [1, 5, 10, 15, 20])
    def test_valid_levels(self, level: int) -> None:
        """Test valid levels (1-20)."""
        result = DnDValidationResult()
        validate_level(level, result)
        assert result.is_valid

    def test_level_zero(self) -> None:
        """Test level 0 is invalid."""
        result = DnDValidationResult()
        validate_level(0, result)
        assert not result.is_valid
        assert result.errors[0].field == "level"

    def test_level_21(self) -> None:
        """Test level 21 is invalid."""
        result = DnDValidationResult()
        validate_level(21, result)
        assert not result.is_valid

    def test_negative_level(self) -> None:
        """Test negative level is invalid."""
        result = DnDValidationResult()
        validate_level(-1, result)
        assert not result.is_valid


class TestValidateAbilityScores:
    """Tests for ability score validation."""

    def test_valid_ability_scores(self) -> None:
        """Test valid ability scores."""
        result = DnDValidationResult()
        scores = {
            "strength": 15,
            "dexterity": 14,
            "constitution": 13,
            "intelligence": 12,
            "wisdom": 10,
            "charisma": 8,
        }
        validate_ability_scores(scores, result)
        assert result.is_valid

    def test_minimum_scores(self) -> None:
        """Test minimum ability scores (all 1s)."""
        result = DnDValidationResult()
        scores = {
            "strength": 1,
            "dexterity": 1,
            "constitution": 1,
            "intelligence": 1,
            "wisdom": 1,
            "charisma": 1,
        }
        validate_ability_scores(scores, result)
        assert result.is_valid

    def test_maximum_scores(self) -> None:
        """Test maximum ability scores (all 20s)."""
        result = DnDValidationResult()
        scores = {
            "strength": 20,
            "dexterity": 20,
            "constitution": 20,
            "intelligence": 20,
            "wisdom": 20,
            "charisma": 20,
        }
        validate_ability_scores(scores, result)
        assert result.is_valid

    def test_missing_ability(self) -> None:
        """Test missing ability score."""
        result = DnDValidationResult()
        scores = {
            "strength": 15,
            "dexterity": 14,
            "constitution": 13,
            "intelligence": 12,
            "wisdom": 10,
            # missing charisma
        }
        validate_ability_scores(scores, result)
        assert not result.is_valid
        assert "charisma" in result.errors[0].message.lower()

    def test_unknown_ability(self) -> None:
        """Test unknown ability score."""
        result = DnDValidationResult()
        scores = {
            "strength": 15,
            "dexterity": 14,
            "constitution": 13,
            "intelligence": 12,
            "wisdom": 10,
            "charisma": 8,
            "luck": 10,  # not a D&D ability
        }
        validate_ability_scores(scores, result)
        assert not result.is_valid
        assert "luck" in result.errors[0].message.lower()

    def test_score_below_minimum(self) -> None:
        """Test ability score below 1."""
        result = DnDValidationResult()
        scores = {
            "strength": 0,
            "dexterity": 14,
            "constitution": 13,
            "intelligence": 12,
            "wisdom": 10,
            "charisma": 8,
        }
        validate_ability_scores(scores, result)
        assert not result.is_valid
        assert "strength" in result.errors[0].field

    def test_score_above_maximum(self) -> None:
        """Test ability score above 20."""
        result = DnDValidationResult()
        scores = {
            "strength": 21,
            "dexterity": 14,
            "constitution": 13,
            "intelligence": 12,
            "wisdom": 10,
            "charisma": 8,
        }
        validate_ability_scores(scores, result)
        assert not result.is_valid

    def test_empty_ability_scores(self) -> None:
        """Test empty ability scores dict."""
        result = DnDValidationResult()
        validate_ability_scores({}, result)
        assert not result.is_valid


class TestValidateName:
    """Tests for name validation."""

    def test_valid_name(self) -> None:
        """Test valid character name."""
        result = DnDValidationResult()
        validate_name("Thorin Oakenshield", result)
        assert result.is_valid

    def test_short_name(self) -> None:
        """Test single character name is valid."""
        result = DnDValidationResult()
        validate_name("X", result)
        assert result.is_valid

    def test_max_length_name(self) -> None:
        """Test max length name (100 chars)."""
        result = DnDValidationResult()
        validate_name("A" * 100, result)
        assert result.is_valid

    def test_name_too_long(self) -> None:
        """Test name over 100 characters."""
        result = DnDValidationResult()
        validate_name("A" * 101, result)
        assert not result.is_valid

    def test_empty_name(self) -> None:
        """Test empty name."""
        result = DnDValidationResult()
        validate_name("", result)
        assert not result.is_valid

    def test_whitespace_name(self) -> None:
        """Test whitespace-only name."""
        result = DnDValidationResult()
        validate_name("   ", result)
        assert not result.is_valid


class TestValidateBackstory:
    """Tests for backstory validation."""

    def test_valid_backstory(self) -> None:
        """Test valid backstory."""
        result = DnDValidationResult()
        validate_backstory("A veteran warrior from the mountain halls.", result)
        assert result.is_valid

    def test_none_backstory(self) -> None:
        """Test None backstory is valid (optional field)."""
        result = DnDValidationResult()
        validate_backstory(None, result)
        assert result.is_valid

    def test_max_length_backstory(self) -> None:
        """Test max length backstory (5000 chars)."""
        result = DnDValidationResult()
        validate_backstory("A" * 5000, result)
        assert result.is_valid

    def test_backstory_too_long(self) -> None:
        """Test backstory over 5000 characters."""
        result = DnDValidationResult()
        validate_backstory("A" * 5001, result)
        assert not result.is_valid


class TestValidateCharacter:
    """Tests for complete character validation."""

    def test_valid_character(self) -> None:
        """Test valid complete character."""
        result = validate_character(
            name="Thorin",
            character_class="fighter",
            race="dwarf",
            level=1,
            ability_scores={
                "strength": 16,
                "dexterity": 12,
                "constitution": 15,
                "intelligence": 10,
                "wisdom": 13,
                "charisma": 8,
            },
            backstory="A veteran warrior.",
        )
        assert result.is_valid
        assert len(result.errors) == 0

    def test_character_with_multiple_errors(self) -> None:
        """Test character with multiple validation errors."""
        result = validate_character(
            name="",
            character_class="necromancer",
            race="orc",
            level=25,
            ability_scores={
                "strength": 0,
            },
        )
        assert not result.is_valid
        assert len(result.errors) >= 4  # name, class, race, level, ability scores


class TestHelperFunctions:
    """Tests for helper functions."""

    def test_is_valid_class_true(self) -> None:
        """Test is_valid_class returns True for valid class."""
        assert is_valid_class("fighter") is True
        assert is_valid_class("Fighter") is True
        assert is_valid_class("WIZARD") is True

    def test_is_valid_class_false(self) -> None:
        """Test is_valid_class returns False for invalid class."""
        assert is_valid_class("necromancer") is False
        assert is_valid_class("") is False

    def test_is_valid_race_true(self) -> None:
        """Test is_valid_race returns True for valid race."""
        assert is_valid_race("human") is True
        assert is_valid_race("Human") is True
        assert is_valid_race("HALF-ELF") is True

    def test_is_valid_race_false(self) -> None:
        """Test is_valid_race returns False for invalid race."""
        assert is_valid_race("orc") is False
        assert is_valid_race("") is False
