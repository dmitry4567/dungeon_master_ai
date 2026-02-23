"""Dice roll parser for extracting dice requests from DM responses."""
import random
import re
from dataclasses import dataclass
from typing import Any


@dataclass
class DiceRequest:
    """Parsed dice roll request from DM response."""

    dice_type: str  # e.g., "d20", "2d6"
    num_dice: int
    die_size: int
    modifier: int
    dc: int | None
    skill: str | None
    reason: str | None

    @property
    def notation(self) -> str:
        """Get standard dice notation."""
        mod = f"+{self.modifier}" if self.modifier > 0 else (
            str(self.modifier) if self.modifier < 0 else ""
        )
        if self.num_dice == 1:
            return f"d{self.die_size}{mod}"
        return f"{self.num_dice}d{self.die_size}{mod}"


@dataclass
class DiceResult:
    """Result of a dice roll."""

    request: DiceRequest
    rolls: list[int]  # Individual die results
    total: int  # Sum of rolls + modifier
    success: bool | None  # None if no DC, else pass/fail

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "type": self.request.notation,
            "dice_type": self.request.dice_type,
            "num_dice": self.request.num_dice,
            "die_size": self.request.die_size,
            "rolls": self.rolls,
            "base_roll": sum(self.rolls),
            "modifier": self.request.modifier,
            "total": self.total,
            "dc": self.request.dc,
            "skill": self.request.skill,
            "reason": self.request.reason,
            "success": self.success,
        }


class DiceParser:
    """Parser for dice roll requests in DM responses."""

    # Pattern to match dice requests like:
    # [DICE: d20+5 DC:15 Skill:Perception Reason:Looking for traps]
    # [DICE: 2d6+3 Reason:Damage roll]
    DICE_PATTERN = re.compile(
        r"\[DICE:\s*"
        r"(?P<num_dice>\d+)?d(?P<die_size>\d+)"
        r"(?P<modifier>[+-]\d+)?"
        r"(?:\s+DC:(?P<dc>\d+))?"
        r"(?:\s+Skill:(?P<skill>[^\s\]]+))?"
        r"(?:\s+Reason:(?P<reason>[^\]]+))?"
        r"\]",
        re.IGNORECASE,
    )

    def parse_dice_requests(self, text: str) -> list[DiceRequest]:
        """Parse all dice requests from DM response text.

        Args:
            text: DM response text

        Returns:
            List of parsed dice requests
        """
        requests = []
        for match in self.DICE_PATTERN.finditer(text):
            num_dice = int(match.group("num_dice") or 1)
            die_size = int(match.group("die_size"))
            modifier_str = match.group("modifier") or "0"
            modifier = int(modifier_str.replace("+", ""))
            dc = int(match.group("dc")) if match.group("dc") else None
            skill = match.group("skill")
            reason = match.group("reason").strip() if match.group("reason") else None

            requests.append(
                DiceRequest(
                    dice_type=f"d{die_size}",
                    num_dice=num_dice,
                    die_size=die_size,
                    modifier=modifier,
                    dc=dc,
                    skill=skill,
                    reason=reason,
                )
            )

        return requests

    def remove_dice_requests(self, text: str) -> str:
        """Remove dice request markers from text.

        Args:
            text: DM response text with dice markers

        Returns:
            Text with dice markers removed
        """
        return self.DICE_PATTERN.sub("", text).strip()

    def roll_dice(self, request: DiceRequest) -> DiceResult:
        """Execute a dice roll.

        Args:
            request: Dice request to roll

        Returns:
            Dice result with rolls and total
        """
        rolls = [random.randint(1, request.die_size) for _ in range(request.num_dice)]
        total = sum(rolls) + request.modifier

        success = None
        if request.dc is not None:
            success = total >= request.dc

        return DiceResult(
            request=request,
            rolls=rolls,
            total=total,
            success=success,
        )

    def parse_and_roll(self, text: str) -> tuple[str, list[DiceResult]]:
        """Parse dice requests from text and roll them.

        Args:
            text: DM response text

        Returns:
            Tuple of (clean text, list of dice results)
        """
        requests = self.parse_dice_requests(text)
        results = [self.roll_dice(req) for req in requests]
        clean_text = self.remove_dice_requests(text)
        return clean_text, results


# Common D&D dice roll helpers
def roll_d20(modifier: int = 0, dc: int | None = None) -> DiceResult:
    """Roll a d20 with optional modifier and DC."""
    parser = DiceParser()
    request = DiceRequest(
        dice_type="d20",
        num_dice=1,
        die_size=20,
        modifier=modifier,
        dc=dc,
        skill=None,
        reason=None,
    )
    return parser.roll_dice(request)


def roll_ability_check(
    ability_modifier: int,
    proficiency_bonus: int = 0,
    dc: int = 10,
    skill: str | None = None,
) -> DiceResult:
    """Roll an ability check."""
    parser = DiceParser()
    request = DiceRequest(
        dice_type="d20",
        num_dice=1,
        die_size=20,
        modifier=ability_modifier + proficiency_bonus,
        dc=dc,
        skill=skill,
        reason=f"{skill} check" if skill else "Ability check",
    )
    return parser.roll_dice(request)


def roll_attack(attack_bonus: int, ac: int) -> DiceResult:
    """Roll an attack against AC."""
    parser = DiceParser()
    request = DiceRequest(
        dice_type="d20",
        num_dice=1,
        die_size=20,
        modifier=attack_bonus,
        dc=ac,
        skill=None,
        reason="Attack roll",
    )
    return parser.roll_dice(request)


def roll_damage(num_dice: int, die_size: int, modifier: int = 0) -> DiceResult:
    """Roll damage dice."""
    parser = DiceParser()
    request = DiceRequest(
        dice_type=f"d{die_size}",
        num_dice=num_dice,
        die_size=die_size,
        modifier=modifier,
        dc=None,
        skill=None,
        reason="Damage roll",
    )
    return parser.roll_dice(request)
