"""Unit tests for dice parser."""
import pytest

from src.services.dice_parser import (
    DiceParser,
    DiceRequest,
    roll_ability_check,
    roll_attack,
    roll_d20,
    roll_damage,
)


class TestDiceParser:
    """Tests for DiceParser class."""

    def setup_method(self):
        self.parser = DiceParser()

    def test_parse_simple_d20(self):
        """Test parsing a simple d20 roll request."""
        text = "Make a perception check. [DICE: d20+5 DC:15 Skill:Perception Reason:Looking for traps]"
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 1
        req = requests[0]
        assert req.num_dice == 1
        assert req.die_size == 20
        assert req.modifier == 5
        assert req.dc == 15
        assert req.skill == "Perception"
        assert req.reason == "Looking for traps"

    def test_parse_multiple_dice(self):
        """Test parsing 2d6 style notation."""
        text = "[DICE: 2d6+3 Reason:Longsword damage]"
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 1
        req = requests[0]
        assert req.num_dice == 2
        assert req.die_size == 6
        assert req.modifier == 3
        assert req.dc is None
        assert req.skill is None
        assert req.reason == "Longsword damage"

    def test_parse_negative_modifier(self):
        """Test parsing negative modifier."""
        text = "[DICE: d20-2 DC:10 Reason:Weak attack]"
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 1
        req = requests[0]
        assert req.modifier == -2

    def test_parse_no_modifier(self):
        """Test parsing without modifier."""
        text = "[DICE: d20 DC:12]"
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 1
        req = requests[0]
        assert req.modifier == 0

    def test_parse_multiple_requests(self):
        """Test parsing multiple dice requests in one text."""
        text = """
        First, make an attack roll. [DICE: d20+7 DC:18 Reason:Attack roll]
        If you hit, roll damage. [DICE: 2d8+4 Reason:Damage]
        """
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 2
        assert requests[0].die_size == 20
        assert requests[0].modifier == 7
        assert requests[1].num_dice == 2
        assert requests[1].die_size == 8

    def test_parse_case_insensitive(self):
        """Test that parsing is case insensitive."""
        text = "[dice: D20+5 dc:15 skill:Athletics reason:Climbing]"
        requests = self.parser.parse_dice_requests(text)

        assert len(requests) == 1
        req = requests[0]
        assert req.die_size == 20
        assert req.dc == 15
        assert req.skill == "Athletics"

    def test_remove_dice_requests(self):
        """Test removing dice markers from text."""
        text = "Make a roll [DICE: d20+5 DC:15] and see what happens."
        clean = self.parser.remove_dice_requests(text)

        assert "[DICE:" not in clean
        assert "Make a roll" in clean
        assert "and see what happens" in clean

    def test_roll_dice_basic(self):
        """Test basic dice rolling."""
        request = DiceRequest(
            dice_type="d20",
            num_dice=1,
            die_size=20,
            modifier=5,
            dc=15,
            skill=None,
            reason=None,
        )
        result = self.parser.roll_dice(request)

        # Check roll is within valid range
        assert 1 <= result.rolls[0] <= 20
        assert result.total == result.rolls[0] + 5
        assert result.success == (result.total >= 15)

    def test_roll_dice_multiple(self):
        """Test rolling multiple dice."""
        request = DiceRequest(
            dice_type="d6",
            num_dice=3,
            die_size=6,
            modifier=2,
            dc=None,
            skill=None,
            reason=None,
        )
        result = self.parser.roll_dice(request)

        assert len(result.rolls) == 3
        for roll in result.rolls:
            assert 1 <= roll <= 6
        assert result.total == sum(result.rolls) + 2
        assert result.success is None  # No DC

    def test_parse_and_roll(self):
        """Test parsing and rolling in one step."""
        text = "Roll for initiative! [DICE: d20+3 DC:10 Reason:Initiative]"
        clean_text, results = self.parser.parse_and_roll(text)

        assert "[DICE:" not in clean_text
        assert len(results) == 1
        assert 1 <= results[0].rolls[0] <= 20

    def test_dice_notation(self):
        """Test dice notation property."""
        request = DiceRequest(
            dice_type="d20",
            num_dice=1,
            die_size=20,
            modifier=5,
            dc=None,
            skill=None,
            reason=None,
        )
        assert request.notation == "d20+5"

        request2 = DiceRequest(
            dice_type="d6",
            num_dice=2,
            die_size=6,
            modifier=-1,
            dc=None,
            skill=None,
            reason=None,
        )
        assert request2.notation == "2d6-1"

        request3 = DiceRequest(
            dice_type="d8",
            num_dice=1,
            die_size=8,
            modifier=0,
            dc=None,
            skill=None,
            reason=None,
        )
        assert request3.notation == "d8"

    def test_to_dict(self):
        """Test converting result to dict."""
        request = DiceRequest(
            dice_type="d20",
            num_dice=1,
            die_size=20,
            modifier=5,
            dc=15,
            skill="Perception",
            reason="Spot check",
        )
        result = self.parser.roll_dice(request)
        data = result.to_dict()

        assert "type" in data
        assert "rolls" in data
        assert "total" in data
        assert "dc" in data
        assert data["skill"] == "Perception"
        assert data["reason"] == "Spot check"


class TestDiceHelpers:
    """Tests for helper dice functions."""

    def test_roll_d20(self):
        """Test roll_d20 helper."""
        result = roll_d20(modifier=5, dc=15)
        assert result.request.die_size == 20
        assert result.request.modifier == 5
        assert result.request.dc == 15

    def test_roll_ability_check(self):
        """Test roll_ability_check helper."""
        result = roll_ability_check(
            ability_modifier=3,
            proficiency_bonus=2,
            dc=12,
            skill="Athletics",
        )
        assert result.request.modifier == 5  # 3 + 2
        assert result.request.dc == 12
        assert result.request.skill == "Athletics"

    def test_roll_attack(self):
        """Test roll_attack helper."""
        result = roll_attack(attack_bonus=7, ac=16)
        assert result.request.modifier == 7
        assert result.request.dc == 16
        assert result.request.reason == "Attack roll"

    def test_roll_damage(self):
        """Test roll_damage helper."""
        result = roll_damage(num_dice=2, die_size=6, modifier=4)
        assert result.request.num_dice == 2
        assert result.request.die_size == 6
        assert result.request.modifier == 4
        assert len(result.rolls) == 2
