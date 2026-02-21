from contextlib import asynccontextmanager
from typing import Any

import redis.asyncio as redis
from redis.asyncio import Redis

from src.core.config import get_settings

settings = get_settings()

_redis_client: Redis | None = None


async def get_redis() -> Redis:
    """Get Redis client instance."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
    return _redis_client


async def close_redis() -> None:
    """Close Redis connection."""
    global _redis_client
    if _redis_client is not None:
        await _redis_client.close()
        _redis_client = None


@asynccontextmanager
async def redis_context():
    """Context manager for Redis operations."""
    client = await get_redis()
    try:
        yield client
    finally:
        pass


class RedisService:
    """Service for Redis operations."""

    def __init__(self, client: Redis):
        self.client = client

    async def get(self, key: str) -> str | None:
        """Get value by key."""
        return await self.client.get(key)

    async def set(
        self,
        key: str,
        value: str,
        expire: int | None = None,
    ) -> bool:
        """Set key-value pair with optional expiration."""
        return await self.client.set(key, value, ex=expire)

    async def delete(self, key: str) -> int:
        """Delete key."""
        return await self.client.delete(key)

    async def hset(self, name: str, mapping: dict[str, Any]) -> int:
        """Set hash fields."""
        return await self.client.hset(name, mapping=mapping)

    async def hgetall(self, name: str) -> dict[str, Any]:
        """Get all hash fields."""
        return await self.client.hgetall(name)

    async def sadd(self, name: str, *values: str) -> int:
        """Add members to a set."""
        return await self.client.sadd(name, *values)

    async def srem(self, name: str, *values: str) -> int:
        """Remove members from a set."""
        return await self.client.srem(name, *values)

    async def smembers(self, name: str) -> set[str]:
        """Get all members of a set."""
        return await self.client.smembers(name)

    async def publish(self, channel: str, message: str) -> int:
        """Publish message to channel."""
        return await self.client.publish(channel, message)

    def pubsub(self):
        """Get pubsub instance."""
        return self.client.pubsub()


async def get_redis_service() -> RedisService:
    """Get Redis service instance."""
    client = await get_redis()
    return RedisService(client)
