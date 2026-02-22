import asyncio
import os
import uuid
from collections.abc import AsyncGenerator, Generator
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from src.core.config import Settings, get_settings
from src.core.database import Base
from src.core.redis import get_redis
from src.models.character import Character
from src.models.user import User

# Import all models to ensure they're registered with Base.metadata
from src.models import scenario  # noqa: F401


# Test database URL - uses same PostgreSQL but different database
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://aidm:aidm@localhost:5432/aidm_test"
)


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Setup test database schema once per session."""
    import asyncio

    async def setup():
        engine = create_async_engine(TEST_DATABASE_URL, echo=False)
        async with engine.begin() as conn:
            # Drop existing tables
            await conn.execute(text("DROP TABLE IF EXISTS scenario_versions CASCADE"))
            await conn.execute(text("DROP TABLE IF EXISTS scenarios CASCADE"))
            await conn.execute(text("DROP TABLE IF EXISTS characters CASCADE"))
            await conn.execute(text("DROP TABLE IF EXISTS users CASCADE"))
            await conn.execute(text("DROP TYPE IF EXISTS scenario_status CASCADE"))
            # Create all tables
            await conn.run_sync(Base.metadata.create_all)
        await engine.dispose()

    asyncio.get_event_loop().run_until_complete(setup())
    yield


@pytest.fixture
def test_settings() -> Settings:
    """Override settings for testing."""
    return Settings(
        database_url=TEST_DATABASE_URL,
        redis_url="redis://localhost:6379/1",
        jwt_secret_key="test-secret-key-for-testing-only",
        app_debug=True,
        app_env="testing",
    )


@pytest_asyncio.fixture
async def test_engine(test_settings: Settings, setup_test_database):
    """Create test database engine."""
    engine = create_async_engine(
        test_settings.database_url,
        echo=False,
    )

    yield engine

    # Clean up data after each test
    async with engine.begin() as conn:
        await conn.execute(text("DELETE FROM scenario_versions"))
        await conn.execute(text("DELETE FROM scenarios"))
        await conn.execute(text("DELETE FROM characters"))
        await conn.execute(text("DELETE FROM users"))

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
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create database session for integration tests."""
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
    # Import app here to avoid early engine creation
    from src.api.main import app
    from src.core.database import get_db

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
        email=f"test-{uuid.uuid4()}@example.com",  # Unique email per test
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


@pytest_asyncio.fixture
async def test_character(test_session: AsyncSession, test_user: User) -> Character:
    """Create a test character for the test user."""
    character = Character(
        id=uuid.uuid4(),
        user_id=test_user.id,
        name="Thorin",
        character_class="fighter",
        race="dwarf",
        level=1,
        ability_scores={
            "strength": 16,
            "dexterity": 12,
            "constitution": 15,
            "intelligence": 10,
            "wisdom": 13,
            "charisma": 8,
        },
        backstory="A veteran warrior from the mountain halls.",
    )
    test_session.add(character)
    await test_session.commit()
    await test_session.refresh(character)
    return character


@pytest_asyncio.fixture
async def other_user(test_session: AsyncSession) -> User:
    """Create another test user."""
    from src.core.security import hash_password

    user = User(
        id=uuid.uuid4(),
        email=f"other-{uuid.uuid4()}@example.com",  # Unique email
        password_hash=hash_password("otherpassword123"),
        name="Other User",
    )
    test_session.add(user)
    await test_session.commit()
    await test_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def other_user_character(
    test_session: AsyncSession, other_user: User
) -> Character:
    """Create a character belonging to another user."""
    character = Character(
        id=uuid.uuid4(),
        user_id=other_user.id,
        name="Legolas",
        character_class="ranger",
        race="elf",
        level=5,
        ability_scores={
            "strength": 10,
            "dexterity": 18,
            "constitution": 12,
            "intelligence": 14,
            "wisdom": 16,
            "charisma": 12,
        },
        backstory="An elven prince from the woodland realm.",
    )
    test_session.add(character)
    await test_session.commit()
    await test_session.refresh(character)
    return character
