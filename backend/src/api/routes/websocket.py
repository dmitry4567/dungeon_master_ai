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
    WSDiceResult,
    WSDMResponseChunk,
    WSDMResponseEnd,
    WSError,
    WSMessageType,
    WSPlayerBroadcast,
    WSPlayerJoin,
    WSPlayerLeave,
    WSStateUpdate,
    WSSystemMessage,
)
from src.services.ai_service import AIService
from src.services.dice_parser import DiceParser
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

                # Parse dice requests from response
                clean_response, dice_results = dice_parser.parse_and_roll(full_response)

                # If there were dice requests, broadcast results
                for result in dice_results:
                    dice_msg = WSDiceResult(
                        player_id=uuid.UUID(user_id),
                        player_name=user_name,
                        dice_type=result.request.notation,
                        base_roll=sum(result.rolls),
                        modifier=result.request.modifier,
                        total=result.total,
                        dc=result.request.dc,
                        skill=result.request.skill,
                        success=result.success,
                    )
                    await manager.broadcast_to_room(room_id, dice_msg.model_dump(mode="json"))

                # Extract state changes and save DM message (fresh DB session)
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
                dice_result_data = (
                    dice_results[0].to_dict() if dice_results else None
                )
                async with get_db_context() as db:
                    session_service = SessionService(db)
                    await session_service.add_dm_message(
                        session_id,
                        full_response,
                        dice_result=dice_result_data,
                        state_delta=state_delta,
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
