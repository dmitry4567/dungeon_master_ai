"""Contract tests for /scenarios endpoints."""
import uuid
from typing import Any
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestListScenarios:
    """Tests for GET /scenarios endpoint."""

    async def test_list_scenarios_empty(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test listing scenarios when user has none."""
        response = await client.get("/api/v1/scenarios", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data == []

    async def test_list_scenarios_filter_by_status(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test filtering scenarios by status."""
        response = await client.get(
            "/api/v1/scenarios?status=draft", headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    async def test_list_scenarios_unauthorized(self, client: AsyncClient) -> None:
        """Test listing scenarios without auth returns 401."""
        response = await client.get("/api/v1/scenarios")
        assert response.status_code == 401


@pytest.mark.asyncio
class TestCreateScenario:
    """Tests for POST /scenarios endpoint."""

    @patch("src.services.scenario_service.ScenarioService.generate_scenario")
    async def test_create_scenario_success(
        self,
        mock_generate: AsyncMock,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        """Test creating a scenario with valid description."""
        # Mock the AI service response
        mock_generate.return_value = {
            "id": str(uuid.uuid4()),
            "title": "Test Adventure",
            "status": "draft",
            "current_version": {
                "id": str(uuid.uuid4()),
                "version": 1,
                "content": {
                    "tone": "dark_fantasy",
                    "difficulty": "intermediate",
                    "players_min": 2,
                    "players_max": 5,
                    "world_lore": "Test lore",
                    "acts": [],
                    "npcs": [],
                    "locations": [],
                },
                "validation_errors": None,
            },
        }

        request_data = {"description": "A dark fantasy adventure in a haunted castle"}

        response = await client.post(
            "/api/v1/scenarios",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert "title" in data
        assert data["status"] == "draft"
        assert "current_version" in data
        assert data["current_version"]["version"] == 1

    async def test_create_scenario_description_too_short(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test creating scenario with too short description returns 400."""
        request_data = {"description": "short"}

        response = await client.post(
            "/api/v1/scenarios",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 400

    async def test_create_scenario_description_too_long(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test creating scenario with too long description returns 400."""
        request_data = {"description": "x" * 2001}

        response = await client.post(
            "/api/v1/scenarios",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 400

    async def test_create_scenario_missing_description(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test creating scenario without description returns 400."""
        response = await client.post(
            "/api/v1/scenarios",
            json={},
            headers=auth_headers,
        )
        assert response.status_code == 400

    async def test_create_scenario_unauthorized(self, client: AsyncClient) -> None:
        """Test creating scenario without auth returns 401."""
        request_data = {"description": "Test adventure"}
        response = await client.post("/api/v1/scenarios", json=request_data)
        assert response.status_code == 401


@pytest.mark.asyncio
class TestGetScenario:
    """Tests for GET /scenarios/{scenarioId} endpoint."""

    async def test_get_scenario_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test getting non-existent scenario returns 404."""
        scenario_id = str(uuid.uuid4())
        response = await client.get(
            f"/api/v1/scenarios/{scenario_id}", headers=auth_headers
        )
        assert response.status_code == 404

    async def test_get_scenario_unauthorized(self, client: AsyncClient) -> None:
        """Test getting scenario without auth returns 401."""
        scenario_id = str(uuid.uuid4())
        response = await client.get(f"/api/v1/scenarios/{scenario_id}")
        assert response.status_code == 401


@pytest.mark.asyncio
class TestRefineScenario:
    """Tests for POST /scenarios/{scenarioId}/refine endpoint."""

    @patch("src.services.scenario_service.ScenarioService.refine_scenario")
    async def test_refine_scenario_success(
        self,
        mock_refine: AsyncMock,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ) -> None:
        """Test refining a scenario with valid prompt."""
        scenario_id = str(uuid.uuid4())
        mock_refine.return_value = {
            "id": scenario_id,
            "title": "Test Adventure (Refined)",
            "status": "draft",
            "current_version": {
                "id": str(uuid.uuid4()),
                "version": 2,
                "content": {
                    "tone": "dark_fantasy",
                    "difficulty": "hardcore",
                    "players_min": 2,
                    "players_max": 5,
                    "world_lore": "Refined lore",
                    "acts": [],
                    "npcs": [],
                    "locations": [],
                },
                "validation_errors": None,
            },
        }

        request_data = {"prompt": "Make it more challenging"}

        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/refine",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["current_version"]["version"] == 2

    async def test_refine_scenario_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test refining non-existent scenario returns 404."""
        scenario_id = str(uuid.uuid4())
        request_data = {"prompt": "Make it better"}

        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/refine",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_refine_scenario_prompt_too_short(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test refining scenario with too short prompt returns 400."""
        scenario_id = str(uuid.uuid4())
        request_data = {"prompt": "hi"}

        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/refine",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 400

    async def test_refine_scenario_prompt_too_long(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test refining scenario with too long prompt returns 400."""
        scenario_id = str(uuid.uuid4())
        request_data = {"prompt": "x" * 1001}

        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/refine",
            json=request_data,
            headers=auth_headers,
        )
        assert response.status_code == 400

    async def test_refine_scenario_unauthorized(self, client: AsyncClient) -> None:
        """Test refining scenario without auth returns 401."""
        scenario_id = str(uuid.uuid4())
        request_data = {"prompt": "Make it better"}
        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/refine", json=request_data
        )
        assert response.status_code == 401


@pytest.mark.asyncio
class TestListScenarioVersions:
    """Tests for GET /scenarios/{scenarioId}/versions endpoint."""

    async def test_list_versions_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test listing versions for non-existent scenario returns 404."""
        scenario_id = str(uuid.uuid4())
        response = await client.get(
            f"/api/v1/scenarios/{scenario_id}/versions", headers=auth_headers
        )
        assert response.status_code == 404

    async def test_list_versions_unauthorized(self, client: AsyncClient) -> None:
        """Test listing versions without auth returns 401."""
        scenario_id = str(uuid.uuid4())
        response = await client.get(f"/api/v1/scenarios/{scenario_id}/versions")
        assert response.status_code == 401


@pytest.mark.asyncio
class TestRestoreScenarioVersion:
    """Tests for POST /scenarios/{scenarioId}/versions/{versionId}/restore endpoint."""

    async def test_restore_version_not_found(
        self, client: AsyncClient, auth_headers: dict[str, str]
    ) -> None:
        """Test restoring non-existent version returns 404."""
        scenario_id = str(uuid.uuid4())
        version_id = str(uuid.uuid4())
        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/versions/{version_id}/restore",
            headers=auth_headers,
        )
        assert response.status_code == 404

    async def test_restore_version_unauthorized(self, client: AsyncClient) -> None:
        """Test restoring version without auth returns 401."""
        scenario_id = str(uuid.uuid4())
        version_id = str(uuid.uuid4())
        response = await client.post(
            f"/api/v1/scenarios/{scenario_id}/versions/{version_id}/restore"
        )
        assert response.status_code == 401
