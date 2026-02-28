import pytest

from src.services.tts_service import TTSService


@pytest.fixture
def tts_service() -> TTSService:
    return TTSService()


def test_preprocess_text_strips_markdown(tts_service: TTSService):
    text = "**Bold** *italic* `code` ~strike~"
    expected = "Bold italic code strike"
    assert tts_service.preprocess_text(text) == expected


def test_preprocess_text_removes_dice_tags(tts_service: TTSService):
    text = "You see a [DICE: d20+5] dragon."
    expected = "You see a dragon."
    assert tts_service.preprocess_text(text) == expected


def test_preprocess_text_normalizes_whitespace(tts_service: TTSService):
    text = "  Hello   world,    this is a   test.  "
    expected = "Hello world, this is a test."
    assert tts_service.preprocess_text(text) == expected


def test_preprocess_text_full_integration(tts_service: TTSService):
    text = "  **The story continues...** [DICE: d6] You find a `potion`.   "
    expected = "The story continues... You find a potion."
    assert tts_service.preprocess_text(text) == expected
