"""Contract tests for /characters endpoints."""
import uuid
from typing import Any

import pytest
from httpx import AsyncClient

from src.models.character import Character


@pytest.mark.asyncio
class TestCharactersList:
    """Tests for GET /characters endpoint."""

    async def test_list_characters_empty(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test listing characters when user has none."""
        response = await client.get("/api/v1/characters", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data == []

    async def test_list_characters_with_data(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
    ) -> None:
        """Test listing characters returns user's characters."""
        response = await client.get("/api/v1/characters", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == test_character.name
        assert data[0]["class"] == test_character.character_class

    async def test_list_characters_unauthorized(self, client: AsyncClient) -> None:
        """Test listing characters without auth returns 401."""
        response = await client.get("/api/v1/characters")
        assert response.status_code == 401


@pytest.mark.asyncio
class TestCreateCharacter:
    """Tests for POST /characters endpoint."""

    async def test_create_character_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating a valid character."""
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == sample_character_data["name"]
        assert data["class"] == sample_character_data["class"]
        assert data["race"] == sample_character_data["race"]
        assert data["level"] == sample_character_data.get("level", 1)
        assert "id" in data
        assert "created_at" in data

    async def test_create_character_invalid_class(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating character with invalid D&D class returns 400."""
        sample_character_data["class"] = "necromancer"
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        assert response.status_code == 400
        data = response.json()
        assert "class" in str(data).lower()

    async def test_create_character_invalid_race(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating character with invalid D&D race returns 400."""
        sample_character_data["race"] = "orc"
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        assert response.status_code == 400
        data = response.json()
        assert "race" in str(data).lower()

    async def test_create_character_invalid_ability_score(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating character with invalid ability score returns 422 (Pydantic validation)."""
        sample_character_data["ability_scores"]["strength"] = 25
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        # Pydantic validates schema constraints, returning 422
        assert response.status_code == 422

    async def test_create_character_missing_ability_score(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating character with missing ability score returns 422 (Pydantic validation)."""
        del sample_character_data["ability_scores"]["charisma"]
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        # Pydantic validates required fields, returning 422
        assert response.status_code == 422

    async def test_create_character_invalid_level(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        sample_character_data: dict[str, Any],
    ) -> None:
        """Test creating character with invalid level returns 422 (Pydantic validation)."""
        sample_character_data["level"] = 25
        response = await client.post(
            "/api/v1/characters",
            json=sample_character_data,
            headers=auth_headers,
        )
        # Pydantic validates level constraints (1-20), returning 422
        assert response.status_code == 422

    async def test_create_character_unauthorized(
        self, client: AsyncClient, sample_character_data: dict[str, Any]
    ) -> None:
        """Test creating character without auth returns 401."""
        response = await client.post("/api/v1/characters", json=sample_character_data)
        assert response.status_code == 401


@pytest.mark.asyncio
class TestGetCharacter:
    """Tests for GET /characters/{id} endpoint."""

    async def test_get_character_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
    ) -> None:
        """Test getting a character by ID."""
        response = await client.get(
            f"/api/v1/characters/{test_character.id}",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_character.id)
        assert data["name"] == test_character.name

    async def test_get_character_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test getting non-existent character returns 404."""
        fake_id = uuid.uuid4()
        response = await client.get(
            f"/api/v1/characters/{fake_id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_get_character_other_user(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_character: Character,
    ) -> None:
        """Test getting another user's character returns 404."""
        response = await client.get(
            f"/api/v1/characters/{other_user_character.id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_get_character_unauthorized(
        self, client: AsyncClient, test_character: Character
    ) -> None:
        """Test getting character without auth returns 401."""
        response = await client.get(f"/api/v1/characters/{test_character.id}")
        assert response.status_code == 401


@pytest.mark.asyncio
class TestUpdateCharacter:
    """Tests for PATCH /characters/{id} endpoint."""

    async def test_update_character_name(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
    ) -> None:
        """Test updating character name."""
        response = await client.patch(
            f"/api/v1/characters/{test_character.id}",
            json={"name": "New Name"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "New Name"

    async def test_update_character_backstory(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
    ) -> None:
        """Test updating character backstory."""
        new_backstory = "A new tale of adventure."
        response = await client.patch(
            f"/api/v1/characters/{test_character.id}",
            json={"backstory": new_backstory},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["backstory"] == new_backstory

    async def test_update_character_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test updating non-existent character returns 404."""
        fake_id = uuid.uuid4()
        response = await client.patch(
            f"/api/v1/characters/{fake_id}",
            json={"name": "New Name"},
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_update_character_other_user(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_character: Character,
    ) -> None:
        """Test updating another user's character returns 404."""
        response = await client.patch(
            f"/api/v1/characters/{other_user_character.id}",
            json={"name": "Hacked Name"},
            headers=auth_headers,
        )
        assert response.status_code == 404


@pytest.mark.asyncio
class TestDeleteCharacter:
    """Tests for DELETE /characters/{id} endpoint."""

    async def test_delete_character_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
    ) -> None:
        """Test deleting a character."""
        response = await client.delete(
            f"/api/v1/characters/{test_character.id}",
            headers=auth_headers,
        )
        assert response.status_code == 204

        # Verify it's deleted
        response = await client.get(
            f"/api/v1/characters/{test_character.id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_delete_character_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test deleting non-existent character returns 404."""
        fake_id = uuid.uuid4()
        response = await client.delete(
            f"/api/v1/characters/{fake_id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_delete_character_other_user(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_character: Character,
    ) -> None:
        """Test deleting another user's character returns 404."""
        response = await client.delete(
            f"/api/v1/characters/{other_user_character.id}",
            headers=auth_headers,
        )
        assert response.status_code == 404

    # Note: Test for 409 when character is in active game will be added
    # in Phase 6 when rooms/sessions are implemented
