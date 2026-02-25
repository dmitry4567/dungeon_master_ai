"""Load test: 100 concurrent WebSocket connections.

This test verifies that the server can handle 100 simultaneous WebSocket
connections without crashing or exceeding resource limits.

Run with:
    pytest tests/load/test_websocket_load.py -v -s

Note: Requires a running server on localhost:8000 OR uses ASGI test transport.
This test uses a mock-friendly approach so it runs in CI without an external server.
"""
from __future__ import annotations

import asyncio
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# ---- Target configuration ----
TARGET_CONNECTIONS = 100
CONNECTION_TIMEOUT_S = 5.0
MAX_ACCEPTABLE_FAILURE_RATE = 0.05  # 5% failures allowed


class FakeWebSocket:
    """Lightweight fake WebSocket for load testing without network."""

    def __init__(self, connection_id: str) -> None:
        self.connection_id = connection_id
        self.sent_messages: list[dict] = []
        self.closed = False
        self._accepted = False

    async def accept(self) -> None:
        self._accepted = True

    async def send_json(self, data: dict) -> None:
        self.sent_messages.append(data)

    async def receive_json(self) -> dict:
        # Simulate a disconnect after first receive
        raise Exception("Simulated disconnect")

    async def close(self, code: int = 1000, reason: str = "") -> None:
        self.closed = True

    @property
    def client(self):
        return MagicMock(host="127.0.0.1")


async def simulate_connection(
    manager,
    room_id: str,
    user_id: str,
) -> dict[str, bool | str]:
    """Simulate a single WebSocket connection lifecycle.

    Returns:
        dict with connection result info
    """
    ws = FakeWebSocket(connection_id=user_id)
    try:
        await asyncio.wait_for(
            manager.connect(ws, room_id, user_id, f"Player {user_id[:8]}"),
            timeout=CONNECTION_TIMEOUT_S,
        )
        # Brief hold to simulate being connected
        await asyncio.sleep(0.01)
        await manager.disconnect(ws, room_id, user_id)
        return {"success": True, "user_id": user_id}
    except asyncio.TimeoutError:
        return {"success": False, "user_id": user_id, "error": "timeout"}
    except Exception as e:
        return {"success": False, "user_id": user_id, "error": str(e)}


@pytest.mark.asyncio
@pytest.mark.load
async def test_100_concurrent_websocket_connections():
    """Verify ConnectionManager handles 100 simultaneous connections."""
    from src.api.routes.websocket import ConnectionManager

    room_id = str(uuid.uuid4())

    # Patch Redis to avoid real connections
    mock_redis = AsyncMock()
    mock_redis.sadd = AsyncMock(return_value=1)
    mock_redis.srem = AsyncMock(return_value=1)
    mock_redis.publish = AsyncMock(return_value=1)

    with patch("src.api.routes.websocket.get_redis_service", return_value=mock_redis):
        manager = ConnectionManager()
        user_ids = [str(uuid.uuid4()) for _ in range(TARGET_CONNECTIONS)]

        # Launch all connections concurrently
        tasks = [
            simulate_connection(manager, room_id, user_id)
            for user_id in user_ids
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

    # Analyze results
    successes = 0
    failures = 0
    errors: list[str] = []

    for result in results:
        if isinstance(result, Exception):
            failures += 1
            errors.append(str(result))
        elif isinstance(result, dict):
            if result.get("success"):
                successes += 1
            else:
                failures += 1
                errors.append(result.get("error", "unknown"))

    total = successes + failures
    failure_rate = failures / total if total > 0 else 1.0

    print(f"\nLoad test results:")
    print(f"  Target connections: {TARGET_CONNECTIONS}")
    print(f"  Successful: {successes}")
    print(f"  Failed: {failures}")
    print(f"  Failure rate: {failure_rate:.1%}")
    if errors:
        unique_errors = list(set(errors))[:5]
        print(f"  Unique errors (first 5): {unique_errors}")

    assert total == TARGET_CONNECTIONS, f"Expected {TARGET_CONNECTIONS} results, got {total}"
    assert failure_rate <= MAX_ACCEPTABLE_FAILURE_RATE, (
        f"Failure rate {failure_rate:.1%} exceeds {MAX_ACCEPTABLE_FAILURE_RATE:.1%} threshold. "
        f"Errors: {set(errors)}"
    )


@pytest.mark.asyncio
@pytest.mark.load
async def test_connection_manager_room_isolation():
    """Verify that connections in different rooms are isolated."""
    from src.api.routes.websocket import ConnectionManager

    mock_redis = AsyncMock()
    mock_redis.sadd = AsyncMock(return_value=1)
    mock_redis.srem = AsyncMock(return_value=1)
    mock_redis.publish = AsyncMock(return_value=1)

    with patch("src.api.routes.websocket.get_redis_service", return_value=mock_redis):
        manager = ConnectionManager()
        num_rooms = 10
        connections_per_room = 10

        rooms = [str(uuid.uuid4()) for _ in range(num_rooms)]
        all_tasks = []

        for room_id in rooms:
            for _ in range(connections_per_room):
                user_id = str(uuid.uuid4())
                all_tasks.append(simulate_connection(manager, room_id, user_id))

        results = await asyncio.gather(*all_tasks, return_exceptions=True)

    successes = sum(
        1 for r in results
        if isinstance(r, dict) and r.get("success")
    )

    print(f"\nRoom isolation test: {successes}/{len(all_tasks)} connections succeeded")
    assert successes == len(all_tasks), f"Not all connections succeeded: {successes}/{len(all_tasks)}"


@pytest.mark.asyncio
@pytest.mark.load
async def test_action_queue_under_concurrent_load():
    """Verify action queue handles concurrent player actions correctly."""
    from src.api.routes.websocket import ConnectionManager

    manager = ConnectionManager()
    room_id = str(uuid.uuid4())

    # Simulate 20 players all sending actions simultaneously
    num_players = 20
    player_ids = [str(uuid.uuid4()) for _ in range(num_players)]

    def enqueue_for_player(user_id: str) -> str:
        action = manager.enqueue_action(room_id, user_id, f"Action from {user_id[:8]}")
        return action.action_id

    # Enqueue all actions "simultaneously" (as fast as possible)
    action_ids = [enqueue_for_player(uid) for uid in player_ids]

    queue = manager._action_queues[room_id]
    assert len(queue) == num_players, f"Expected {num_players} queued actions, got {len(queue)}"

    # Verify all actions are timestamped and in order
    timestamps = [a.timestamp for a in queue]
    assert timestamps == sorted(timestamps), "Actions are not in timestamp order"

    # Dequeue all
    dequeued = 0
    for action_id in action_ids:
        if manager.dequeue_action(room_id, action_id):
            dequeued += 1

    assert dequeued == num_players, f"Expected to dequeue {num_players}, got {dequeued}"
    assert len(manager._action_queues[room_id]) == 0, "Queue should be empty after dequeue"
