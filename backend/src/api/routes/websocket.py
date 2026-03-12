"""WebSocket handler for real-time game sessions."""
import asyncio
import json
import time
import uuid
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from src.core.database import get_db_context
from src.core.logging import get_logger
from src.core.redis import get_redis_service
from src.core.security import verify_token_type
from src.schemas.websocket import (
    WSDiceRequest,
    WSDiceResult,
    WSDMResponseChunk,
    WSDMResponseEnd,
    WSError,
    WSMessageType,
    WSPlayerBroadcast,
    WSPlayerJoin,
    WSPlayerLeave,
    WSStateUpdate,
)
from src.services.ai_service import AIService
from src.services.dice_parser import DiceParser, DiceRequest
from src.services.session_service import SessionService
from src.services.state_extractor import StateExtractor

logger = get_logger(__name__)

router = APIRouter(tags=["WebSocket"])


def _calculate_progress(world_state: dict, scenario_content: dict) -> float:
    """Считает % пройденных обязательных сцен сценария."""
    acts = scenario_content.get("acts", [])
    total = sum(
        1 for act in acts for scene in act.get("scenes", []) if scene.get("mandatory", False)
    )
    if total == 0:
        return 0.0
    completed_ids = set(world_state.get("completed_scenes", []))
    done = sum(
        1 for act in acts for scene in act.get("scenes", [])
        if scene.get("mandatory", False) and scene.get("id") in completed_ids
    )
    return round(min(done / total * 100, 100.0), 1)


_MAX_RECONNECT_HISTORY = 50  # Max messages stored for reconnect sync
_ACTION_QUEUE_WINDOW_MS = 500  # Window to collect simultaneous actions (ms)


@dataclass(order=True)
class QueuedAction:
    """A player action queued for processing."""

    timestamp: float  # Unix timestamp when action arrived
    user_id: str = field(compare=False)
    content: str = field(compare=False)
    action_id: str = field(compare=False, default_factory=lambda: str(uuid.uuid4()))


class ConnectionManager:
    """Manages WebSocket connections and Redis pub/sub for rooms."""

    def __init__(self):
        self.active_connections: dict[str, dict[str, WebSocket]] = {}  # room_id -> {user_id: ws}
        self.user_info: dict[str, dict[str, Any]] = {}  # user_id -> {name, character_name, etc}
        self._subscribe_tasks: dict[str, asyncio.Task] = {}
        # Pending dice requests: request_id -> {request_data, player_id, room_id, ...}
        self.pending_dice_requests: dict[str, dict[str, Any]] = {}
        # Recent message history per room for reconnect sync: room_id -> [msg, ...]
        self._room_message_history: dict[str, list[dict[str, Any]]] = {}
        # Per-room action processing locks to serialize AI calls
        self._room_locks: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)
        # Per-room action queues: room_id -> [QueuedAction]
        self._action_queues: dict[str, list[QueuedAction]] = defaultdict(list)

    async def connect(
        self,
        websocket: WebSocket,
        room_id: str,
        user_id: str,
        user_name: str,
        character_name: str | None = None,
        last_message_id: str | None = None,
    ) -> None:
        """Add a new WebSocket connection.

        Args:
            websocket: The WebSocket connection
            room_id: Room identifier
            user_id: User identifier
            user_name: Display name of the user
            character_name: Character name if applicable
            last_message_id: If reconnecting, ID of last received message for sync
        """
        await websocket.accept()

        is_reconnect = user_id in self.user_info

        if room_id not in self.active_connections:
            self.active_connections[room_id] = {}

        self.active_connections[room_id][user_id] = websocket
        self.user_info[user_id] = {
            "name": user_name,
            "character_name": character_name,
            "room_id": room_id,
        }

        # Track connection in Redis
        redis = await get_redis_service()
        await redis.sadd(f"room:{room_id}:connections", user_id)

        # Start Redis subscription if not already running
        if room_id not in self._subscribe_tasks:
            self._subscribe_tasks[room_id] = asyncio.create_task(
                self._subscribe_to_room(room_id)
            )

        # On reconnect: send missed messages
        if is_reconnect or last_message_id is not None:
            await self._sync_missed_messages(websocket, room_id, last_message_id)

        logger.info(
            "User connected to room: user_id=%s, room_id=%s",
            user_id,
            room_id,
        )

    async def disconnect(self, websocket: WebSocket, room_id: str, user_id: str) -> None:
        """Remove a WebSocket connection."""
        if room_id in self.active_connections:
            self.active_connections[room_id].pop(user_id, None)
            if not self.active_connections[room_id]:
                del self.active_connections[room_id]
                # Cancel subscription task
                if room_id in self._subscribe_tasks:
                    self._subscribe_tasks[room_id].cancel()
                    del self._subscribe_tasks[room_id]

        self.user_info.pop(user_id, None)

        # Remove from Redis
        redis = await get_redis_service()
        await redis.srem(f"room:{room_id}:connections", user_id)

        logger.info(
            "User disconnected from room: user_id=%s, room_id=%s",
            user_id,
            room_id,
        )

    async def send_personal(self, user_id: str, message: dict) -> None:
        """Send a message to a specific user."""
        info = self.user_info.get(user_id)
        if not info:
            return

        room_id = info.get("room_id")
        if not room_id:
            return

        ws = self.active_connections.get(room_id, {}).get(user_id)
        if ws:
            try:
                await ws.send_json(message)
            except Exception as e:
                logger.error("Failed to send personal message to user=%s: %s", user_id, str(e))

    def _record_room_message(self, room_id: str, message: dict) -> None:
        """Store message in room history for reconnect sync."""
        if room_id not in self._room_message_history:
            self._room_message_history[room_id] = []
        history = self._room_message_history[room_id]
        history.append(message)
        # Keep only the last N messages
        if len(history) > _MAX_RECONNECT_HISTORY:
            self._room_message_history[room_id] = history[-_MAX_RECONNECT_HISTORY:]

    async def _sync_missed_messages(
        self,
        websocket: WebSocket,
        room_id: str,
        last_message_id: str | None,
    ) -> None:
        """Send missed messages to a reconnecting client.

        Args:
            websocket: The reconnected client's WebSocket
            room_id: Room to sync
            last_message_id: ID of the last message the client received, or None for all
        """
        history = self._room_message_history.get(room_id, [])
        if not history:
            return

        missed: list[dict] = []
        if last_message_id is None:
            missed = history
        else:
            # Find messages after last_message_id
            found = False
            for msg in history:
                if found:
                    missed.append(msg)
                elif str(msg.get("message_id", msg.get("id", ""))) == last_message_id:
                    found = True

        if missed:
            try:
                sync_envelope = {
                    "type": "sync_missed_messages",
                    "count": len(missed),
                    "messages": missed,
                }
                await websocket.send_json(sync_envelope)
                logger.info(
                    "Synced %s missed messages on reconnect: user in room=%s",
                    len(missed),
                    room_id,
                )
            except Exception as e:
                logger.error("Failed to sync missed messages: %s", str(e))

    def get_room_lock(self, room_id: str) -> asyncio.Lock:
        """Get per-room lock for serializing AI processing."""
        return self._room_locks[room_id]

    def enqueue_action(self, room_id: str, user_id: str, content: str) -> QueuedAction:
        """Add a player action to the room's processing queue.

        Actions are timestamped on arrival. If multiple players act simultaneously
        (within _ACTION_QUEUE_WINDOW_MS), they are queued and processed in order.

        Args:
            room_id: Room identifier
            user_id: Player user ID
            content: Action content/text

        Returns:
            The queued action
        """
        action = QueuedAction(
            timestamp=time.time(),
            user_id=user_id,
            content=content,
        )
        self._action_queues[room_id].append(action)
        self._action_queues[room_id].sort()  # Sort by timestamp
        return action

    def dequeue_action(self, room_id: str, action_id: str) -> QueuedAction | None:
        """Remove and return a specific action from the queue."""
        queue = self._action_queues[room_id]
        for i, action in enumerate(queue):
            if action.action_id == action_id:
                return queue.pop(i)
        return None

    def get_queue_position(self, room_id: str, action_id: str) -> int:
        """Return 1-based position of action in queue, or 0 if not found."""
        queue = self._action_queues[room_id]
        for i, action in enumerate(queue):
            if action.action_id == action_id:
                return i + 1
        return 0

    async def broadcast_to_room(self, room_id: str, message: dict) -> None:
        """Broadcast a message to all users in a room via Redis pub/sub."""
        # Record in history for reconnect sync
        self._record_room_message(room_id, message)
        redis = await get_redis_service()
        await redis.publish(f"room:{room_id}", json.dumps(message))

    async def broadcast_to_room_direct(self, room_id: str, message: dict) -> None:
        """Broadcast directly to local connections (for streaming)."""
        connections = self.active_connections.get(room_id, {})
        disconnected = []

        for user_id, ws in connections.items():
            try:
                await ws.send_json(message)
            except Exception as e:
                logger.error("Failed to send to user=%s: %s", user_id, str(e))
                disconnected.append(user_id)

        # Clean up disconnected
        for user_id in disconnected:
            await self.disconnect(
                connections[user_id], room_id, user_id
            )

    async def _subscribe_to_room(self, room_id: str) -> None:
        """Subscribe to Redis channel for a room and forward messages."""
        try:
            redis = await get_redis_service()
            pubsub = redis.pubsub()
            await pubsub.subscribe(f"room:{room_id}")

            async for message in pubsub.listen():
                if message["type"] == "message":
                    try:
                        data = json.loads(message["data"])
                        await self.broadcast_to_room_direct(room_id, data)
                    except json.JSONDecodeError:
                        continue
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error("Redis subscription error for room=%s: %s", room_id, str(e))


manager = ConnectionManager()


async def _process_dm_response_completion(
    manager: ConnectionManager,
    state_extractor: StateExtractor,
    room_id: str,
    session_id: uuid.UUID,
    full_response: str,
    world_state: dict,
    scenario_content: str,
    dice_result_data: dict | None,
) -> None:
    """Process state extraction and save DM message after dice roll (or if no dice needed)."""
    state_delta = None
    try:
        state_update = await state_extractor.extract_state_update(
            full_response,
            world_state,
            scenario_content,
        )

        logger.info(
            "State extraction result: has_changes=%s, events=%s, location=%s, scene=%s, flags=%s",
            state_update.has_changes(),
            state_update.events_occurred,
            state_update.location_changed,
            state_update.scene_completed,
            list(state_update.flags_changed.keys()),
        )

        if state_update.has_changes():
            async with get_db_context() as db:
                session_service = SessionService(db)
                # Apply state changes
                new_world_state = state_extractor.apply_state_update(
                    world_state, state_update
                )
                await session_service.update_world_state(
                    session_id, new_world_state
                )

            # Broadcast state update
            progress = _calculate_progress(new_world_state, scenario_content)
            state_msg = WSStateUpdate(world_state=new_world_state, progress_percentage=progress)
            logger.info("Broadcasting state update to room %s: %s (progress=%.1f%%)", room_id, new_world_state, progress)
            await manager.broadcast_to_room(
                room_id, state_msg.model_dump(mode="json")
            )

            state_delta = state_update.to_dict()
        else:
            logger.info("No state changes detected, skipping broadcast")

    except Exception as e:
        logger.error("State extraction error: %s", str(e), exc_info=True)

    # Save DM message
    async with get_db_context() as db:
        session_service = SessionService(db)
        await session_service.add_dm_message(
            session_id,
            full_response,
            dice_result=dice_result_data,
            state_delta=state_delta,
        )


async def get_user_from_token(token: str) -> dict | None:
    """Verify token and get user info."""
    payload = verify_token_type(token, "access")
    if not payload:
        return None
    return {"id": payload.get("sub")}


@router.websocket("/ws/session/{room_id}")
async def websocket_session(
    websocket: WebSocket,
    room_id: str,
    token: str,
    last_message_id: str | None = None,
):
    """WebSocket endpoint for game session communication.

    All users in the room receive:
    - Messages from other players
    - Streaming DM responses (token by token)
    - State updates
    - Dice roll results

    The LLM responds in the same language as the player's message.

    On reconnect, pass `last_message_id` query parameter to receive missed messages.
    """
    # Authenticate user
    user_data = await get_user_from_token(token)
    if not user_data:
        await websocket.close(code=4001, reason="Invalid token")
        return

    user_id = user_data["id"]

    # Get session and verify user is in the room (fresh DB session for init)
    try:
        async with get_db_context() as db:
            session_service = SessionService(db)
            session = await session_service.get_session_by_room(uuid.UUID(room_id))
            if not session:
                await websocket.close(code=4004, reason="Session not found")
                return

            session_id = session.id
            world_state = session.world_state

            # Get player info
            players = await session_service.get_session_players(session_id)
            player = next((p for p in players if p["id"] == user_id), None)
            if not player:
                await websocket.close(code=4003, reason="Not a member of this room")
                return

            user_name = player.get("name", "Unknown")
            character = player.get("character", {})
            character_name = character.get("name")

    except Exception as e:
        logger.error("Session lookup error: %s", str(e))
        await websocket.close(code=4000, reason="Session error")
        return

    # Connect (pass last_message_id for reconnect sync)
    await manager.connect(
        websocket, room_id, user_id, user_name, character_name,
        last_message_id=last_message_id,
    )

    # Notify room of player join
    join_msg = WSPlayerJoin(
        player_id=uuid.UUID(user_id),
        player_name=user_name,
        character_name=character_name,
    )
    await manager.broadcast_to_room(room_id, join_msg.model_dump(mode="json"))

    # Initialize services
    ai_service = AIService()
    dice_parser = DiceParser()
    state_extractor = StateExtractor()

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_json()
            
            await websocket.send_json({
                "type": "ack"
            })
            
            msg_type = data.get("type")

            if msg_type == WSMessageType.PLAYER_MESSAGE:
                content = data.get("content", "").strip()
                if not content:
                    continue

                # Enqueue action with timestamp for ordered processing
                queued = manager.enqueue_action(room_id, user_id, content)
                queue_pos = manager.get_queue_position(room_id, queued.action_id)

                # Notify player of their position if they must wait
                if queue_pos > 1:
                    wait_msg = {
                        "type": "action_queued",
                        "action_id": queued.action_id,
                        "queue_position": queue_pos,
                        "message": f"Your action is queued (position {queue_pos}). Please wait...",
                    }
                    await manager.send_personal(user_id, wait_msg)

                # Acquire room lock to serialize AI processing
                room_lock = manager.get_room_lock(room_id)
                async with room_lock:
                    # Remove from queue now that we hold the lock
                    manager.dequeue_action(room_id, queued.action_id)

                # Use fresh DB session for each message processing
                async with get_db_context() as db:
                    session_service = SessionService(db)

                    # Get context for AI BEFORE saving player message to avoid duplication
                    scenario_content = await session_service.get_scenario_content(session_id)
                    conversation_history = await session_service.get_conversation_history(session_id)

                    # Refresh session for latest world state
                    session_obj = await session_service.get_session(session_id)
                    world_state = session_obj.world_state

                    # Save player message
                    player_msg = await session_service.add_player_message(
                        session_id,
                        uuid.UUID(user_id),
                        content,
                    )

                    # Broadcast player message to room
                    broadcast = WSPlayerBroadcast(
                        message_id=player_msg.id,
                        author_id=uuid.UUID(user_id),
                        author_name=user_name,
                        character_name=character_name,
                        content=content,
                        created_at=player_msg.created_at,
                    )
                    await manager.broadcast_to_room(room_id, broadcast.model_dump(mode="json"))

                # Generate DM response with streaming (no DB needed during streaming)
                dm_message_id = uuid.uuid4()
                full_response = ""

                try:
                    await websocket.send_json({
                        "type": "processing"
                    })
  
                    # Stream DM response token by token
                    chunk_count = 0
                    logger.info("Starting DM response streaming: room_id=%s", room_id)

                    async for chunk in ai_service.stream_dm_response(
                        player_message=content,
                        scenario_content=scenario_content,
                        world_state=world_state,
                        players=players,
                        conversation_history=conversation_history,
                    ):
                        chunk_count += 1
                        full_response += chunk
                        # Send chunk to all players
                        chunk_msg = WSDMResponseChunk(
                            chunk=chunk,
                            message_id=dm_message_id,
                        )
                        await manager.broadcast_to_room_direct(
                            room_id, chunk_msg.model_dump(mode="json")
                        )

                    logger.info("DM streaming complete: chunk_count=%s, room_id=%s", chunk_count, room_id)

                    # Send end marker
                    end_msg = WSDMResponseEnd(
                        message_id=dm_message_id,
                        full_content=full_response,
                    )
                    await manager.broadcast_to_room(room_id, end_msg.model_dump(mode="json"))

                except Exception as e:
                    logger.error("AI streaming error: %s", str(e))
                    error_msg = WSError(
                        error="ai_error",
                        message="Failed to generate DM response",
                    )
                    await manager.send_personal(user_id, error_msg.model_dump(mode="json"))
                    continue

                # Parse dice requests from response (without rolling)
                dice_requests = dice_parser.parse_dice_requests(full_response)

                # If there are dice requests, send request to the player who performed the action
                if dice_requests:
                    # Take the first dice request (typically one per action)
                    dice_req = dice_requests[0]
                    request_id = uuid.uuid4()

                    # Store pending request with all context needed for later processing
                    manager.pending_dice_requests[str(request_id)] = {
                        "request": dice_req,
                        "player_id": user_id,
                        "player_name": user_name,
                        "room_id": room_id,
                        "session_id": session_id,
                        "dm_response": full_response,
                        "world_state": world_state,
                        "scenario_content": scenario_content,
                        "conversation_history": conversation_history,
                        "players": players,
                        "player_message": content,
                    }

                    # Send dice request to the player
                    dice_request_msg = WSDiceRequest(
                        request_id=request_id,
                        target_player_id=uuid.UUID(user_id),
                        target_player_name=user_name,
                        dice_type=dice_req.dice_type,
                        num_dice=dice_req.num_dice,
                        modifier=dice_req.modifier,
                        dc=dice_req.dc,
                        skill=dice_req.skill,
                        reason=dice_req.reason,
                    )
                    # Send to the specific player who needs to roll
                    await manager.send_personal(user_id, dice_request_msg.model_dump(mode="json"))

                    # Don't process state/save yet - wait for dice roll
                    continue

                # No dice requests - proceed with state extraction and save
                await _process_dm_response_completion(
                    manager=manager,
                    state_extractor=state_extractor,
                    room_id=room_id,
                    session_id=session_id,
                    full_response=full_response,
                    world_state=world_state,
                    scenario_content=scenario_content,
                    dice_result_data=None,
                )

            elif msg_type == WSMessageType.DICE_ROLL:
                # Player sent their dice roll
                request_id = data.get("request_id")
                rolls = data.get("rolls", [])

                if not request_id or request_id not in manager.pending_dice_requests:
                    error_msg = WSError(
                        error="invalid_dice_roll",
                        message="No pending dice request found",
                    )
                    await manager.send_personal(user_id, error_msg.model_dump(mode="json"))
                    continue

                # Get pending request
                pending = manager.pending_dice_requests.pop(request_id)
                dice_req: DiceRequest = pending["request"]

                # Validate rolls
                if len(rolls) != dice_req.num_dice:
                    error_msg = WSError(
                        error="invalid_dice_roll",
                        message=f"Expected {dice_req.num_dice} dice, got {len(rolls)}",
                    )
                    await manager.send_personal(user_id, error_msg.model_dump(mode="json"))
                    # Put request back
                    manager.pending_dice_requests[request_id] = pending
                    continue

                # Calculate result
                base_roll = sum(rolls)
                total = base_roll + dice_req.modifier
                success = None
                if dice_req.dc is not None:
                    success = total >= dice_req.dc

                # Broadcast dice result to all players
                dice_msg = WSDiceResult(
                    player_id=uuid.UUID(pending["player_id"]),
                    player_name=pending["player_name"],
                    dice_type=dice_req.notation,
                    base_roll=base_roll,
                    modifier=dice_req.modifier,
                    total=total,
                    dc=dice_req.dc,
                    skill=dice_req.skill,
                    success=success,
                )
                await manager.broadcast_to_room(pending["room_id"], dice_msg.model_dump(mode="json"))

                # Build dice result data for storage
                dice_result_data = {
                    "type": dice_req.notation,
                    "dice_type": dice_req.dice_type,
                    "num_dice": dice_req.num_dice,
                    "die_size": dice_req.die_size,
                    "rolls": rolls,
                    "base_roll": base_roll,
                    "modifier": dice_req.modifier,
                    "total": total,
                    "dc": dice_req.dc,
                    "skill": dice_req.skill,
                    "reason": dice_req.reason,
                    "success": success,
                }

                # Format result message for AI continuation
                success_text = "SUCCESS" if success else "FAILURE" if success is not None else ""
                dice_result_text = (
                    f"[DICE RESULT: {dice_req.notation} rolled {base_roll}"
                    f"{'+' + str(dice_req.modifier) if dice_req.modifier > 0 else str(dice_req.modifier) if dice_req.modifier < 0 else ''}"
                    f" = {total}"
                    f"{' vs DC ' + str(dice_req.dc) if dice_req.dc else ''}"
                    f"{' - ' + success_text if success_text else ''}]"
                )

                # Generate continuation from AI based on dice result
                continuation_message_id = uuid.uuid4()
                continuation_response = ""

                try:
                    async for chunk in ai_service.stream_dm_response(
                        player_message=dice_result_text,
                        scenario_content=pending["scenario_content"],
                        world_state=pending["world_state"],
                        players=pending["players"],
                        conversation_history=pending["conversation_history"] + [
                            {"role": "user", "content": pending["player_message"]},
                            {"role": "assistant", "content": pending["dm_response"]},
                        ],
                    ):
                        continuation_response += chunk
                        chunk_msg = WSDMResponseChunk(
                            chunk=chunk,
                            message_id=continuation_message_id,
                        )
                        await manager.broadcast_to_room_direct(
                            pending["room_id"], chunk_msg.model_dump(mode="json")
                        )

                    # Send end marker
                    end_msg = WSDMResponseEnd(
                        message_id=continuation_message_id,
                        full_content=continuation_response,
                    )
                    await manager.broadcast_to_room(pending["room_id"], end_msg.model_dump(mode="json"))

                except Exception as e:
                    logger.error("AI continuation error: %s", str(e))
                    # Even if continuation fails, we still process the original response

                # Combine original response + continuation for storage
                full_combined_response = pending["dm_response"] + "\n\n" + continuation_response

                await _process_dm_response_completion(
                    manager=manager,
                    state_extractor=state_extractor,
                    room_id=pending["room_id"],
                    session_id=pending["session_id"],
                    full_response=full_combined_response,
                    world_state=pending["world_state"],
                    scenario_content=pending["scenario_content"],
                    dice_result_data=dice_result_data,
                )

    except WebSocketDisconnect:
        logger.info("User disconnected: user_id=%s", user_id)
        manager.disconnect(websocket)
    except Exception as e:
        logger.exception("WebSocket error for user=%s: %s", user_id, str(e))
    finally:
        # Disconnect and notify room
        await manager.disconnect(websocket, room_id, user_id)

        leave_msg = WSPlayerLeave(
            player_id=uuid.UUID(user_id),
            player_name=user_name,
        )
        await manager.broadcast_to_room(room_id, leave_msg.model_dump(mode="json"))
