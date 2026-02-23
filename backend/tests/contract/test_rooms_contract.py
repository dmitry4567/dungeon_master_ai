"""Contract tests for /rooms endpoints."""
from __future__ import annotations

import uuid

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security import create_access_token
from src.models.character import Character
from src.models.room import Room, RoomPlayer, RoomStatus, RoomPlayerStatus
from src.models.scenario import Scenario, ScenarioStatus, ScenarioVersion
from src.models.user import User


@pytest_asyncio.fixture
async def test_scenario_version(
    test_session: AsyncSession, test_user: User
) -> ScenarioVersion:
    """Create a scenario with a version for room tests."""
    scenario = Scenario(
        id=uuid.uuid4(),
        creator_id=test_user.id,
        title="Test Adventure",
        status=ScenarioStatus.PUBLISHED,
    )
    test_session.add(scenario)
    await test_session.flush()

    version = ScenarioVersion(
        id=uuid.uuid4(),
        scenario_id=scenario.id,
        version=1,
        content={
            "tone": "heroic",
            "difficulty": "beginner",
            "players_min": 2,
            "players_max": 5,
            "world_lore": "A brave new world",
            "acts": [{"id": "act_1", "entry_condition": "session_start", "exit_conditions": [], "scenes": []}],
            "npcs": [],
            "locations": [],
        },
        user_prompt="Test scenario",
    )
    test_session.add(version)
    await test_session.flush()

    scenario.current_version_id = version.id
    await test_session.commit()
    await test_session.refresh(version)
    return version


@pytest_asyncio.fixture
async def other_user_auth_headers(other_user: User) -> dict[str, str]:
    """Generate auth headers for the other user."""
    token = create_access_token({"sub": str(other_user.id)})
    return {"Authorization": f"Bearer {token}"}


class TestCreateRoom:
    """Tests for POST /rooms."""

    @pytest.mark.asyncio
    async def test_create_room_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """201: Room created successfully."""
        response = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Epic Adventure Room",
                "scenario_version_id": str(test_scenario_version.id),
                "max_players": 4,
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Epic Adventure Room"
        assert data["max_players"] == 4
        assert data["status"] == "waiting"
        assert "id" in data
        assert "players" in data
        # Host should be automatically added as a player
        assert len(data["players"]) == 1
        assert data["players"][0]["is_host"] is True
        assert data["players"][0]["status"] == "approved"

    @pytest.mark.asyncio
    async def test_create_room_default_max_players(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """201: Room created with default max_players=5."""
        response = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Default Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        assert response.status_code == 201
        assert response.json()["max_players"] == 5

    @pytest.mark.asyncio
    async def test_create_room_validation_error(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ):
        """422: Validation error for invalid data."""
        response = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "ab",  # Too short (min 3)
                "scenario_version_id": str(uuid.uuid4()),
            },
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_create_room_invalid_scenario_version(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ):
        """404: Scenario version not found."""
        response = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Ghost Room",
                "scenario_version_id": str(uuid.uuid4()),
            },
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_create_room_unauthorized(
        self,
        client: AsyncClient,
        test_scenario_version: ScenarioVersion,
    ):
        """401: Unauthorized without token."""
        response = await client.post(
            "/api/v1/rooms",
            json={
                "name": "No Auth Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        assert response.status_code in (401, 403)


class TestListRooms:
    """Tests for GET /rooms."""

    @pytest.mark.asyncio
    async def test_list_rooms_empty(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ):
        """200: Empty list when no rooms exist."""
        response = await client.get("/api/v1/rooms", headers=auth_headers)
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_list_rooms_with_rooms(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: List rooms returns created rooms."""
        # Create a room first
        await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Listed Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        response = await client.get("/api/v1/rooms", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        room = data[0]
        assert "id" in room
        assert "name" in room
        assert "status" in room
        assert "player_count" in room
        assert "max_players" in room

    @pytest.mark.asyncio
    async def test_list_rooms_filter_by_status(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Filter rooms by status."""
        await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Waiting Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        response = await client.get(
            "/api/v1/rooms",
            headers=auth_headers,
            params={"status": "waiting"},
        )
        assert response.status_code == 200
        for room in response.json():
            assert room["status"] == "waiting"


class TestGetRoom:
    """Tests for GET /rooms/{roomId}."""

    @pytest.mark.asyncio
    async def test_get_room_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Get room details."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Detail Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.get(f"/api/v1/rooms/{room_id}", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == room_id
        assert data["name"] == "Detail Room"
        assert "players" in data
        assert "scenario" in data

    @pytest.mark.asyncio
    async def test_get_room_not_found(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ):
        """404: Room not found."""
        response = await client.get(
            f"/api/v1/rooms/{uuid.uuid4()}", headers=auth_headers
        )
        assert response.status_code == 404


class TestJoinRoom:
    """Tests for POST /rooms/{roomId}/join."""

    @pytest.mark.asyncio
    async def test_join_room_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Join room successfully."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Join Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_join_room_already_joined(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """409: Already in room."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Double Join Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )
        response = await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )
        assert response.status_code == 409

    @pytest.mark.asyncio
    async def test_join_room_not_found(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
    ):
        """404: Room not found."""
        response = await client.post(
            f"/api/v1/rooms/{uuid.uuid4()}/join", headers=auth_headers
        )
        assert response.status_code == 404


class TestApproveDeclinePlayer:
    """Tests for POST /rooms/{roomId}/players/{playerId}/approve and /decline."""

    @pytest.mark.asyncio
    async def test_approve_player_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user: User,
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Approve player join request."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Approve Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )

        # Get room to find the player entry
        room_resp = await client.get(f"/api/v1/rooms/{room_id}", headers=auth_headers)
        players = room_resp.json()["players"]
        pending_player = next(
            p for p in players if p["user_id"] == str(other_user.id)
        )

        response = await client.post(
            f"/api/v1/rooms/{room_id}/players/{pending_player['id']}/approve",
            headers=auth_headers,
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_decline_player_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user: User,
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Decline player join request."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Decline Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )

        room_resp = await client.get(f"/api/v1/rooms/{room_id}", headers=auth_headers)
        players = room_resp.json()["players"]
        pending_player = next(
            p for p in players if p["user_id"] == str(other_user.id)
        )

        response = await client.post(
            f"/api/v1/rooms/{room_id}/players/{pending_player['id']}/decline",
            headers=auth_headers,
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_approve_not_host(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """403: Non-host cannot approve."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Auth Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/players/{uuid.uuid4()}/approve",
            headers=other_user_auth_headers,
        )
        assert response.status_code == 403


class TestReadyStatus:
    """Tests for POST /rooms/{roomId}/ready."""

    @pytest.mark.asyncio
    async def test_toggle_ready_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
        test_scenario_version: ScenarioVersion,
    ):
        """200: Toggle ready status."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Ready Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/ready",
            headers=auth_headers,
            json={
                "character_id": str(test_character.id),
                "ready": True,
            },
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_ready_with_invalid_character(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """400: Character not found or not owned by user."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Bad Char Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/ready",
            headers=auth_headers,
            json={
                "character_id": str(uuid.uuid4()),
                "ready": True,
            },
        )
        assert response.status_code == 400


class TestStartGame:
    """Tests for POST /rooms/{roomId}/start."""

    @pytest.mark.asyncio
    async def test_start_game_not_all_ready(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """400: Cannot start when not all players are ready."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Start Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/start", headers=auth_headers
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_start_game_not_host(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """403: Only host can start the game."""
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Host Only Room",
                "scenario_version_id": str(test_scenario_version.id),
            },
        )
        room_id = create_resp.json()["id"]

        response = await client.post(
            f"/api/v1/rooms/{room_id}/start", headers=other_user_auth_headers
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_start_game_success(
        self,
        client: AsyncClient,
        auth_headers: dict[str, str],
        test_character: Character,
        other_user: User,
        other_user_character: Character,
        other_user_auth_headers: dict[str, str],
        test_scenario_version: ScenarioVersion,
    ):
        """200: Start game when all players ready."""
        # Create room
        create_resp = await client.post(
            "/api/v1/rooms",
            headers=auth_headers,
            json={
                "name": "Full Game Room",
                "scenario_version_id": str(test_scenario_version.id),
                "max_players": 2,
            },
        )
        room_id = create_resp.json()["id"]

        # Host marks ready
        await client.post(
            f"/api/v1/rooms/{room_id}/ready",
            headers=auth_headers,
            json={"character_id": str(test_character.id), "ready": True},
        )

        # Other player joins
        await client.post(
            f"/api/v1/rooms/{room_id}/join", headers=other_user_auth_headers
        )

        # Host approves
        room_resp = await client.get(f"/api/v1/rooms/{room_id}", headers=auth_headers)
        players = room_resp.json()["players"]
        pending_player = next(
            p for p in players if p["user_id"] == str(other_user.id)
        )
        await client.post(
            f"/api/v1/rooms/{room_id}/players/{pending_player['id']}/approve",
            headers=auth_headers,
        )

        # Other player marks ready
        await client.post(
            f"/api/v1/rooms/{room_id}/ready",
            headers=other_user_auth_headers,
            json={"character_id": str(other_user_character.id), "ready": True},
        )

        # Host starts game
        response = await client.post(
            f"/api/v1/rooms/{room_id}/start", headers=auth_headers
        )
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert "room_id" in data
        assert data["room_id"] == room_id
        assert "world_state" in data
