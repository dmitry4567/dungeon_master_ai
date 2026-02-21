"""Contract tests for authentication endpoints."""

import pytest
from httpx import AsyncClient


class TestRegisterContract:
    """Contract tests for POST /api/v1/auth/register."""

    @pytest.mark.asyncio
    async def test_register_success(
        self,
        client: AsyncClient,
        sample_user_data: dict,
    ):
        """Test successful user registration returns 201 with auth response."""
        response = await client.post("/api/v1/auth/register", json=sample_user_data)

        assert response.status_code == 201

        data = response.json()
        assert "user_id" in data
        assert data["email"] == sample_user_data["email"]
        assert data["name"] == sample_user_data["name"]
        assert "tokens" in data
        assert "access_token" in data["tokens"]
        assert "refresh_token" in data["tokens"]
        assert data["tokens"]["token_type"] == "bearer"
        assert "expires_in" in data["tokens"]

    @pytest.mark.asyncio
    async def test_register_duplicate_email(
        self,
        client: AsyncClient,
        test_user,
    ):
        """Test registration with existing email returns 409."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "test@example.com",
                "password": "newpassword123",
                "name": "Another User",
            },
        )

        assert response.status_code == 409

        data = response.json()
        assert data["detail"]["error"] == "email_exists"
        assert "message" in data["detail"]

    @pytest.mark.asyncio
    async def test_register_invalid_email(
        self,
        client: AsyncClient,
    ):
        """Test registration with invalid email returns 422."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "password": "password123",
                "name": "Test User",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_short_password(
        self,
        client: AsyncClient,
    ):
        """Test registration with short password returns 422."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "valid@example.com",
                "password": "short",
                "name": "Test User",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_short_name(
        self,
        client: AsyncClient,
    ):
        """Test registration with short name returns 422."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "valid@example.com",
                "password": "password123",
                "name": "X",
            },
        )

        assert response.status_code == 422


class TestLoginContract:
    """Contract tests for POST /api/v1/auth/login."""

    @pytest.mark.asyncio
    async def test_login_success(
        self,
        client: AsyncClient,
        test_user,
    ):
        """Test successful login returns auth response."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "testpassword123",
            },
        )

        assert response.status_code == 200

        data = response.json()
        assert data["user_id"] == str(test_user.id)
        assert data["email"] == test_user.email
        assert data["name"] == test_user.name
        assert "tokens" in data
        assert "access_token" in data["tokens"]
        assert "refresh_token" in data["tokens"]

    @pytest.mark.asyncio
    async def test_login_wrong_password(
        self,
        client: AsyncClient,
        test_user,
    ):
        """Test login with wrong password returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "wrongpassword",
            },
        )

        assert response.status_code == 401

        data = response.json()
        assert data["detail"]["error"] == "invalid_credentials"

    @pytest.mark.asyncio
    async def test_login_nonexistent_email(
        self,
        client: AsyncClient,
    ):
        """Test login with nonexistent email returns 401."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "anypassword",
            },
        )

        assert response.status_code == 401

        data = response.json()
        assert data["detail"]["error"] == "invalid_credentials"


class TestRefreshContract:
    """Contract tests for POST /api/v1/auth/refresh."""

    @pytest.mark.asyncio
    async def test_refresh_success(
        self,
        client: AsyncClient,
        test_user,
    ):
        """Test successful token refresh."""
        login_response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "testpassword123",
            },
        )
        refresh_token = login_response.json()["tokens"]["refresh_token"]

        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )

        assert response.status_code == 200

        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert "expires_in" in data

    @pytest.mark.asyncio
    async def test_refresh_invalid_token(
        self,
        client: AsyncClient,
    ):
        """Test refresh with invalid token returns 401."""
        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid-token"},
        )

        assert response.status_code == 401

        data = response.json()
        assert data["detail"]["error"] == "invalid_token"

    @pytest.mark.asyncio
    async def test_refresh_with_access_token(
        self,
        client: AsyncClient,
        test_user,
    ):
        """Test refresh with access token instead of refresh token returns 401."""
        login_response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "testpassword123",
            },
        )
        access_token = login_response.json()["tokens"]["access_token"]

        response = await client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": access_token},
        )

        assert response.status_code == 401


class TestAppleSignInContract:
    """Contract tests for POST /api/v1/auth/apple."""

    @pytest.mark.asyncio
    async def test_apple_signin_invalid_token(
        self,
        client: AsyncClient,
    ):
        """Test Apple sign in with invalid token returns 401."""
        response = await client.post(
            "/api/v1/auth/apple",
            json={
                "identity_token": "invalid-apple-token",
                "authorization_code": "invalid-code",
            },
        )

        assert response.status_code == 401

        data = response.json()
        assert data["detail"]["error"] == "apple_auth_error"

    @pytest.mark.asyncio
    async def test_apple_signin_missing_fields(
        self,
        client: AsyncClient,
    ):
        """Test Apple sign in with missing fields returns 422."""
        response = await client.post(
            "/api/v1/auth/apple",
            json={
                "identity_token": "some-token",
            },
        )

        assert response.status_code == 422
