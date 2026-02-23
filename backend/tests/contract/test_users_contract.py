"""Contract tests for user endpoints."""

import pytest
from httpx import AsyncClient


class TestGetCurrentUserContract:
    """Contract tests for GET /api/v1/users/me."""

    @pytest.mark.asyncio
    async def test_get_current_user_success(
        self,
        client: AsyncClient,
        test_user,
        auth_headers: dict,
    ):
        """Test get current user returns user profile."""
        response = await client.get("/api/v1/users/me", headers=auth_headers)

        assert response.status_code == 200

        data = response.json()
        assert data["id"] == str(test_user.id)
        assert data["email"] == test_user.email
        assert data["name"] == test_user.name
        assert "created_at" in data
        assert "updated_at" in data

    @pytest.mark.asyncio
    async def test_get_current_user_no_auth(
        self,
        client: AsyncClient,
    ):
        """Test get current user without auth returns 403."""
        response = await client.get("/api/v1/users/me")

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_get_current_user_invalid_token(
        self,
        client: AsyncClient,
    ):
        """Test get current user with invalid token returns 401."""
        response = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": "Bearer invalid-token"},
        )

        assert response.status_code == 401


class TestUpdateCurrentUserContract:
    """Contract tests for PATCH /api/v1/users/me."""

    @pytest.mark.asyncio
    async def test_update_name_success(
        self,
        client: AsyncClient,
        test_user,
        auth_headers: dict,
    ):
        """Test update user name returns updated profile."""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"name": "Updated Name"},
        )

        assert response.status_code == 200

        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["id"] == str(test_user.id)
        assert data["email"] == test_user.email

    @pytest.mark.asyncio
    async def test_update_avatar_success(
        self,
        client: AsyncClient,
        test_user,
        auth_headers: dict,
    ):
        """Test update avatar URL returns updated profile."""
        avatar_url = "https://example.com/avatar.png"
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"avatar_url": avatar_url},
        )

        assert response.status_code == 200

        data = response.json()
        assert data["avatar_url"] == avatar_url

    @pytest.mark.asyncio
    async def test_update_no_changes(
        self,
        client: AsyncClient,
        test_user,
        auth_headers: dict,
    ):
        """Test update with empty body returns current profile."""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={},
        )

        assert response.status_code == 200

        data = response.json()
        assert data["name"] == test_user.name

    @pytest.mark.asyncio
    async def test_update_name_too_short(
        self,
        client: AsyncClient,
        auth_headers: dict,
    ):
        """Test update with short name returns 422."""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"name": "X"},
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_update_no_auth(
        self,
        client: AsyncClient,
    ):
        """Test update without auth returns 403."""
        response = await client.patch(
            "/api/v1/users/me",
            json={"name": "New Name"},
        )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_update_invalid_token(
        self,
        client: AsyncClient,
    ):
        """Test update with invalid token returns 401."""
        response = await client.patch(
            "/api/v1/users/me",
            headers={"Authorization": "Bearer invalid-token"},
            json={"name": "New Name"},
        )

        assert response.status_code == 401
