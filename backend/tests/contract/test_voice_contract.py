"""Contract tests for voice TTS API endpoint."""

from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_tts_endpoint_contract(client: AsyncClient, auth_headers: dict) -> None:
    """Test TTS endpoint contract.

    Verifies:
    - Endpoint accepts POST with text
    - Returns audio_url and duration
    - Requires authentication
    """
    # Test with valid request
    response = await client.post(
        "/api/v1/voice/tts",
        json={"text": "Hello, this is a test."},
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert "audio_url" in data
    assert "duration_seconds" in data
    assert "text" in data
    assert isinstance(data["audio_url"], str)
    assert isinstance(data["duration_seconds"], (int, float))


@pytest.mark.asyncio
async def test_tts_endpoint_requires_auth(client: AsyncClient) -> None:
    """Test TTS endpoint requires authentication."""
    response = await client.post(
        "/api/v1/voice/tts",
        json={"text": "Hello"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_tts_endpoint_validation(client: AsyncClient, auth_headers: dict) -> None:
    """Test TTS endpoint request validation."""
    # Empty text should fail
    response = await client.post(
        "/api/v1/voice/tts",
        json={"text": ""},
        headers=auth_headers,
    )
    assert response.status_code == 422

    # Missing text should fail
    response = await client.post(
        "/api/v1/voice/tts",
        json={},
        headers=auth_headers,
    )
    assert response.status_code == 422
