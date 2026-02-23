"""Session service for managing game sessions and messages."""
import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.models.message import MessageRole, SessionMessage
from src.models.room import Room, RoomPlayer, RoomPlayerStatus, RoomStatus
from src.models.scenario import ScenarioVersion
from src.models.session import GameSession

logger = logging.getLogger(__name__)


class SessionService:
    """Service for game session management."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create_session(self, room_id: uuid.UUID) -> GameSession:
        """Create a new game session for a room.

        Args:
            room_id: ID of the room to create session for

        Returns:
            Created game session

        Raises:
            ValueError: If room not found or not ready to start
        """
        # Get room with scenario
        result = await self.db.execute(
            select(Room)
            .where(Room.id == room_id)
            .options(
                selectinload(Room.scenario_version).selectinload(ScenarioVersion.scenario),
                selectinload(Room.players),
            )
        )
        room = result.scalar_one_or_none()
        if not room:
            raise ValueError("Room not found")

        # Check if session already exists
        existing = await self.db.execute(
            select(GameSession).where(GameSession.room_id == room_id)
        )
        if existing.scalar_one_or_none():
            raise ValueError("Session already exists for this room")

        # Build initial world state from scenario
        scenario_version = room.scenario_version
        content = scenario_version.content if scenario_version else {}

        initial_world_state = {
            "current_act": content.get("acts", [{}])[0].get("id", "act_1") if content.get("acts") else "act_1",
            "current_scene": None,
            "current_location": content.get("locations", [{}])[0].get("id") if content.get("locations") else None,
            "completed_scenes": [],
            "flags": {},
            "combat_active": False,
            "turn_order": [],
        }

        session = GameSession(
            id=uuid.uuid4(),
            room_id=room_id,
            world_state=initial_world_state,
        )
        self.db.add(session)
        await self.db.commit()

        # Reload with relationships
        return await self.get_session(session.id)

    async def get_session(self, session_id: uuid.UUID) -> GameSession:
        """Get a game session by ID.

        Args:
            session_id: Session ID

        Returns:
            Game session with messages

        Raises:
            ValueError: If session not found
        """
        result = await self.db.execute(
            select(GameSession)
            .where(GameSession.id == session_id)
            .options(
                selectinload(GameSession.messages).selectinload(SessionMessage.author),
                selectinload(GameSession.room).selectinload(Room.scenario_version).selectinload(ScenarioVersion.scenario),
                selectinload(GameSession.room).selectinload(Room.players).selectinload(RoomPlayer.user),
                selectinload(GameSession.room).selectinload(Room.players).selectinload(RoomPlayer.character),
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Session not found")
        return session

    async def get_session_by_room(self, room_id: uuid.UUID) -> GameSession | None:
        """Get a game session by room ID.

        Args:
            room_id: Room ID

        Returns:
            Game session or None
        """
        result = await self.db.execute(
            select(GameSession)
            .where(GameSession.room_id == room_id)
            .options(
                selectinload(GameSession.messages).selectinload(SessionMessage.author),
                selectinload(GameSession.room).selectinload(Room.scenario_version).selectinload(ScenarioVersion.scenario),
                selectinload(GameSession.room).selectinload(Room.players).selectinload(RoomPlayer.user),
                selectinload(GameSession.room).selectinload(Room.players).selectinload(RoomPlayer.character),
            )
        )
        return result.scalar_one_or_none()

    async def add_player_message(
        self,
        session_id: uuid.UUID,
        author_id: uuid.UUID,
        content: str,
    ) -> SessionMessage:
        """Add a player message to the session.

        Args:
            session_id: Session ID
            author_id: ID of the player sending the message
            content: Message content

        Returns:
            Created message
        """
        message = SessionMessage(
            id=uuid.uuid4(),
            session_id=session_id,
            author_id=author_id,
            role=MessageRole.PLAYER,
            content=content,
        )
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def add_dm_message(
        self,
        session_id: uuid.UUID,
        content: str,
        dice_result: dict | None = None,
        state_delta: dict | None = None,
    ) -> SessionMessage:
        """Add a DM message to the session.

        Args:
            session_id: Session ID
            content: Message content
            dice_result: Optional dice roll result
            state_delta: Optional state changes

        Returns:
            Created message
        """
        message = SessionMessage(
            id=uuid.uuid4(),
            session_id=session_id,
            author_id=None,  # DM has no author
            role=MessageRole.DM,
            content=content,
            dice_result=dice_result,
            state_delta=state_delta,
        )
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def add_system_message(
        self,
        session_id: uuid.UUID,
        content: str,
    ) -> SessionMessage:
        """Add a system message to the session.

        Args:
            session_id: Session ID
            content: Message content

        Returns:
            Created message
        """
        message = SessionMessage(
            id=uuid.uuid4(),
            session_id=session_id,
            author_id=None,
            role=MessageRole.SYSTEM,
            content=content,
        )
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def get_conversation_history(
        self,
        session_id: uuid.UUID,
        limit: int = 15,
    ) -> list[dict[str, str]]:
        """Get conversation history for AI context.

        Args:
            session_id: Session ID
            limit: Maximum number of messages

        Returns:
            List of messages in OpenAI format
        """
        result = await self.db.execute(
            select(SessionMessage)
            .where(SessionMessage.session_id == session_id)
            .order_by(SessionMessage.created_at.desc())
            .limit(limit)
        )
        messages = list(reversed(result.scalars().all()))

        history = []
        for msg in messages:
            if msg.role == MessageRole.PLAYER:
                history.append({"role": "user", "content": msg.content})
            elif msg.role == MessageRole.DM:
                history.append({"role": "assistant", "content": msg.content})
            # Skip system messages for AI context

        return history

    async def update_world_state(
        self,
        session_id: uuid.UUID,
        world_state: dict[str, Any],
    ) -> GameSession:
        """Update the world state for a session.

        Args:
            session_id: Session ID
            world_state: New world state

        Returns:
            Updated session
        """
        session = await self.get_session(session_id)
        session.world_state = world_state
        await self.db.commit()
        await self.db.refresh(session)
        return session

    async def end_session(self, session_id: uuid.UUID) -> GameSession:
        """End a game session.

        Args:
            session_id: Session ID

        Returns:
            Updated session
        """
        session = await self.get_session(session_id)
        session.ended_at = datetime.now(UTC)

        # Update room status
        room = session.room
        room.status = RoomStatus.COMPLETED
        room.completed_at = datetime.now(UTC)

        await self.db.commit()
        await self.db.refresh(session)

        logger.info(
            f"Session {session_id} ended",
            extra={"session_id": str(session_id)},
        )

        return session

    async def get_session_players(
        self,
        session_id: uuid.UUID,
    ) -> list[dict[str, Any]]:
        """Get players for a session with their characters.

        Args:
            session_id: Session ID

        Returns:
            List of player info dicts
        """
        session = await self.get_session(session_id)
        room = session.room

        players = []
        for rp in room.players:
            if rp.status not in (RoomPlayerStatus.READY, RoomPlayerStatus.APPROVED):
                continue

            player_info = {
                "id": str(rp.user_id),
                "name": rp.user.name if rp.user else "Unknown",
                "is_host": rp.is_host,
            }

            if rp.character:
                player_info["character"] = {
                    "id": str(rp.character.id),
                    "name": rp.character.name,
                    "class": rp.character.character_class,
                    "race": rp.character.race,
                    "level": rp.character.level,
                    "ability_scores": rp.character.ability_scores,
                }

            players.append(player_info)

        return players

    async def get_scenario_content(
        self,
        session_id: uuid.UUID,
    ) -> dict[str, Any]:
        """Get scenario content for a session.

        Args:
            session_id: Session ID

        Returns:
            Scenario content dict
        """
        session = await self.get_session(session_id)
        room = session.room
        scenario_version = room.scenario_version

        if not scenario_version:
            return {}

        content = scenario_version.content or {}
        content["title"] = scenario_version.scenario.title if scenario_version.scenario else "Unknown"

        return content
