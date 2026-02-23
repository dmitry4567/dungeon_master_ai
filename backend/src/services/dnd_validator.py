"""D&D 5e rules validator for character creation and updates."""
from __future__ import annotations

from dataclasses import dataclass

# Valid D&D 5e Player's Handbook classes
VALID_CLASSES = frozenset(
    {
        "barbarian",
        "bard",
        "cleric",
        "druid",
        "fighter",
        "monk",
        "paladin",
        "ranger",
        "rogue",
        "sorcerer",
        "warlock",
        "wizard",
    }
)

# Valid D&D 5e Player's Handbook races
VALID_RACES = frozenset(
    {
        "dragonborn",
        "dwarf",
        "elf",
        "gnome",
        "half-elf",
        "halfling",
        "half-orc",
        "human",
        "tiefling",
    }
)

# Ability score names
ABILITY_NAMES = frozenset(
    {
        "strength",
        "dexterity",
        "constitution",
        "intelligence",
        "wisdom",
        "charisma",
    }
)

# Constraints
MIN_ABILITY_SCORE = 1
MAX_ABILITY_SCORE = 20
MIN_LEVEL = 1
MAX_LEVEL = 20
MIN_NAME_LENGTH = 1
MAX_NAME_LENGTH = 100
MAX_BACKSTORY_LENGTH = 5000


@dataclass
class ValidationError:
    """Validation error with field and message."""

    field: str
    message: str


class DnDValidationResult:
    """Result of D&D 5e validation."""

    def __init__(self) -> None:
        self.errors: list[ValidationError] = []

    @property
    def is_valid(self) -> bool:
        """Check if validation passed."""
        return len(self.errors) == 0

    def add_error(self, field: str, message: str) -> None:
        """Add validation error."""
        self.errors.append(ValidationError(field=field, message=message))


def validate_class(character_class: str, result: DnDValidationResult) -> None:
    """Validate D&D 5e class."""
    if not character_class:
        result.add_error("class", "Class is required")
        return

    normalized = character_class.lower().strip()
    if normalized not in VALID_CLASSES:
        valid_list = ", ".join(sorted(VALID_CLASSES))
        result.add_error("class", f"Invalid class '{character_class}'. Valid classes: {valid_list}")


def validate_race(race: str, result: DnDValidationResult) -> None:
    """Validate D&D 5e race."""
    if not race:
        result.add_error("race", "Race is required")
        return

    normalized = race.lower().strip()
    if normalized not in VALID_RACES:
        valid_list = ", ".join(sorted(VALID_RACES))
        result.add_error("race", f"Invalid race '{race}'. Valid races: {valid_list}")


def validate_level(level: int, result: DnDValidationResult) -> None:
    """Validate character level (1-20)."""
    if level < MIN_LEVEL or level > MAX_LEVEL:
        result.add_error("level", f"Level must be between {MIN_LEVEL} and {MAX_LEVEL}")


def validate_ability_scores(ability_scores: dict[str, int], result: DnDValidationResult) -> None:
    """Validate ability scores (all six required, values 1-20)."""
    if not ability_scores:
        result.add_error("ability_scores", "Ability scores are required")
        return

    # Check for missing abilities
    provided = set(ability_scores.keys())
    missing = ABILITY_NAMES - provided
    if missing:
        result.add_error("ability_scores", f"Missing ability scores: {', '.join(sorted(missing))}")

    # Check for unknown abilities
    unknown = provided - ABILITY_NAMES
    if unknown:
        result.add_error("ability_scores", f"Unknown ability scores: {', '.join(sorted(unknown))}")

    # Validate values
    for ability, value in ability_scores.items():
        if ability in ABILITY_NAMES:
            if not isinstance(value, int):
                result.add_error(f"ability_scores.{ability}", "Ability score must be an integer")
            elif value < MIN_ABILITY_SCORE or value > MAX_ABILITY_SCORE:
                result.add_error(
                    f"ability_scores.{ability}",
                    f"Ability score must be between {MIN_ABILITY_SCORE} and {MAX_ABILITY_SCORE}",
                )


def validate_name(name: str, result: DnDValidationResult) -> None:
    """Validate character name."""
    if not name or not name.strip():
        result.add_error("name", "Name is required")
        return

    if len(name) < MIN_NAME_LENGTH:
        result.add_error("name", f"Name must be at least {MIN_NAME_LENGTH} character")
    elif len(name) > MAX_NAME_LENGTH:
        result.add_error("name", f"Name must be at most {MAX_NAME_LENGTH} characters")


def validate_backstory(backstory: str | None, result: DnDValidationResult) -> None:
    """Validate character backstory (optional, max 5000 chars)."""
    if backstory is not None and len(backstory) > MAX_BACKSTORY_LENGTH:
        result.add_error("backstory", f"Backstory must be at most {MAX_BACKSTORY_LENGTH} characters")


def validate_character(
    *,
    name: str,
    character_class: str,
    race: str,
    level: int = 1,
    ability_scores: dict[str, int],
    backstory: str | None = None,
) -> DnDValidationResult:
    """
    Validate a complete character against D&D 5e rules.

    Returns validation result with any errors.
    """
    result = DnDValidationResult()

    validate_name(name, result)
    validate_class(character_class, result)
    validate_race(race, result)
    validate_level(level, result)
    validate_ability_scores(ability_scores, result)
    validate_backstory(backstory, result)

    return result


def is_valid_class(character_class: str) -> bool:
    """Check if class is valid D&D 5e class."""
    return character_class.lower().strip() in VALID_CLASSES


def is_valid_race(race: str) -> bool:
    """Check if race is valid D&D 5e race."""
    return race.lower().strip() in VALID_RACES
