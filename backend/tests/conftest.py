import asyncio
import uuid
from collections.abc import AsyncGenerator, Generator
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from src.api.main import app
from src.core.config import Settings, get_settings
from src.core.database import Base, get_db
from src.core.redis import get_redis
from src.models.user import User


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_settings() -> Settings:
    """Override settings for testing."""
    return Settings(
        database_url="sqlite+aiosqlite:///:memory:",
        redis_url="redis://localhost:6379/1",
        jwt_secret_key="test-secret-key-for-testing-only",
        app_debug=True,
        app_env="testing",
    )


@pytest_asyncio.fixture
async def test_engine(test_settings: Settings):
    """Create test database engine."""
    engine = create_async_engine(
        test_settings.database_url,
        echo=False,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def test_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create test database session."""
    async_session_maker = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with async_session_maker() as session:
        yield session


@pytest_asyncio.fixture
async def mock_redis() -> AsyncMock:
    """Mock Redis client."""
    mock = AsyncMock()
    mock.get.return_value = None
    mock.set.return_value = True
    mock.delete.return_value = 1
    mock.ping.return_value = True
    return mock


@pytest_asyncio.fixture
async def client(
    test_session: AsyncSession,
    mock_redis: AsyncMock,
    test_settings: Settings,
) -> AsyncGenerator[AsyncClient, None]:
    """Create test HTTP client."""

    async def override_get_db():
        yield test_session

    async def override_get_redis():
        return mock_redis

    def override_get_settings():
        return test_settings

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_redis] = override_get_redis
    app.dependency_overrides[get_settings] = override_get_settings

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_user(test_session: AsyncSession) -> User:
    """Create a test user."""
    from src.core.security import hash_password

    user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        password_hash=hash_password("testpassword123"),
        name="Test User",
    )
    test_session.add(user)
    await test_session.commit()
    await test_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_user: User) -> dict[str, str]:
    """Generate authorization headers for test user."""
    from src.core.security import create_access_token

    token = create_access_token({"sub": str(test_user.id)})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def mock_anthropic() -> MagicMock:
    """Mock Anthropic client."""
    mock = MagicMock()
    mock.messages.create = AsyncMock(
        return_value=MagicMock(
            content=[MagicMock(text="AI response")],
            usage=MagicMock(input_tokens=100, output_tokens=50),
        )
    )
    return mock


@pytest.fixture
def sample_user_data() -> dict[str, Any]:
    """Sample user registration data."""
    return {
        "email": "newuser@example.com",
        "password": "securepassword123",
        "name": "New User",
    }


@pytest.fixture
def sample_character_data() -> dict[str, Any]:
    """Sample character creation data."""
    return {
        "name": "Thorin",
        "class": "fighter",
        "race": "dwarf",
        "level": 1,
        "ability_scores": {
            "strength": 16,
            "dexterity": 12,
            "constitution": 15,
            "intelligence": 10,
            "wisdom": 13,
            "charisma": 8,
        },
        "backstory": "A veteran warrior from the mountain halls.",
    }


@pytest.fixture
def sample_scenario_data() -> dict[str, Any]:
    """Sample scenario creation data."""
    return {
        "description": "An abandoned dwarven mine where an ancient evil has awakened. "
        "The party must find an artifact and stop the undead."
    }
