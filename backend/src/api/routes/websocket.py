"""WebSocket handler for real-time game sessions."""
import asyncio
import json
import logging
import uuid
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from src.core.database import get_db_context
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

logger = logging.getLogger(__name__)

router = APIRouter(tags=["WebSocket"])


class ConnectionManager:
    """Manages WebSocket connections and Redis pub/sub for rooms."""

    def __init__(self):
        self.active_connections: dict[str, dict[str, WebSocket]] = {}  # room_id -> {user_id: ws}
        self.user_info: dict[str, dict[str, Any]] = {}  # user_id -> {name, character_name, etc}
        self._subscribe_tasks: dict[str, asyncio.Task] = {}
        # Pending dice requests: request_id -> {request_data, player_id, room_id, ...}
        self.pending_dice_requests: dict[str, dict[str, Any]] = {}

    async def connect(
        self,
        websocket: WebSocket,
        room_id: str,
        user_id: str,
        user_name: str,
        character_name: str | None = None,
    ) -> None:
        """Add a new WebSocket connection."""
        await websocket.accept()

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

        logger.info(
            f"User {user_id} connected to room {room_id}",
            extra={"user_id": user_id, "room_id": room_id},
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
            f"User {user_id} disconnected from room {room_id}",
            extra={"user_id": user_id, "room_id": room_id},
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
                logger.error(f"Failed to send personal message to {user_id}: {e}")

    async def broadcast_to_room(self, room_id: str, message: dict) -> None:
        """Broadcast a message to all users in a room via Redis pub/sub."""
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
                logger.error(f"Failed to send to {user_id}: {e}")
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
            logger.error(f"Redis subscription error for room {room_id}: {e}")


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
            state_msg = WSStateUpdate(world_state=new_world_state)
            await manager.broadcast_to_room(
                room_id, state_msg.model_dump(mode="json")
            )

            state_delta = state_update.to_dict()

    except Exception as e:
        logger.error(f"State extraction error: {e}")

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
):
    """WebSocket endpoint for game session communication.

    All users in the room receive:
    - Messages from other players
    - Streaming DM responses (token by token)
    - State updates
    - Dice roll results

    The LLM responds in the same language as the player's message.
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
        logger.error(f"Session lookup error: {e}")
        await websocket.close(code=4000, reason="Session error")
        return

    # Connect
    await manager.connect(
        websocket, room_id, user_id, user_name, character_name
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
            msg_type = data.get("type")

            if msg_type == WSMessageType.PLAYER_MESSAGE:
                content = data.get("content", "").strip()
                if not content:
                    continue

                # Use fresh DB session for each message processing
                async with get_db_context() as db:
                    session_service = SessionService(db)

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

                    # Get context for AI
                    scenario_content = await session_service.get_scenario_content(session_id)
                    conversation_history = await session_service.get_conversation_history(session_id)

                    # Refresh session for latest world state
                    session_obj = await session_service.get_session(session_id)
                    world_state = session_obj.world_state

                # Generate DM response with streaming (no DB needed during streaming)
                dm_message_id = uuid.uuid4()
                full_response = ""

                try:
                    # Stream DM response token by token
                    async for chunk in ai_service.stream_dm_response(
                        player_message=content,
                        scenario_content=scenario_content,
                        world_state=world_state,
                        players=players,
                        conversation_history=conversation_history,
                    ):
                        full_response += chunk
                        # Send chunk to all players
                        chunk_msg = WSDMResponseChunk(
                            chunk=chunk,
                            message_id=dm_message_id,
                        )
                        await manager.broadcast_to_room_direct(
                            room_id, chunk_msg.model_dump(mode="json")
                        )

                    # Send end marker
                    end_msg = WSDMResponseEnd(
                        message_id=dm_message_id,
                        full_content=full_response,
                    )
                    await manager.broadcast_to_room(room_id, end_msg.model_dump(mode="json"))

                except Exception as e:
                    logger.error(f"AI streaming error: {e}")
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
                    logger.error(f"AI continuation error: {e}")
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
        logger.info(f"User {user_id} disconnected")
    except Exception as e:
        logger.exception(f"WebSocket error for user {user_id}: {e}")
    finally:
        # Disconnect and notify room
        await manager.disconnect(websocket, room_id, user_id)

        leave_msg = WSPlayerLeave(
            player_id=uuid.UUID(user_id),
            player_name=user_name,
        )
        await manager.broadcast_to_room(room_id, leave_msg.model_dump(mode="json"))
