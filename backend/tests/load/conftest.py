"""Load test configuration - bypasses database setup fixture."""
import pytest


@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Override DB setup for load tests - not needed here."""
    yield
