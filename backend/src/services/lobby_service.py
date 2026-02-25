"""Lobby service for managing game rooms and player coordination."""
import asyncio
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.core.database import get_db_context
from src.core.logging import get_logger
from src.models.character import Character
from src.models.room import Room, RoomPlayer, RoomPlayerStatus, RoomStatus
from src.models.scenario import Scenario, ScenarioStatus, ScenarioVersion
from src.models.session import GameSession
from src.services.ai_service import AIService
from src.services.session_service import SessionService

logger = get_logger(__name__)


class LobbyService:
    """Service for room/lobby management."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create_room(
        self,
        host_id: uuid.UUID,
        name: str,
        scenario_version_id: uuid.UUID,
        max_players: int = 5,
        character_id: uuid.UUID | None = None,
    ) -> Room:
        """Create a new game room.

        Args:
            host_id: ID of the user creating the room
            name: Room display name
            scenario_version_id: ID of the scenario version to use
            max_players: Maximum number of players (1-5, 1 for single player)
            character_id: Required character for single player games

        Returns:
            Created room with host as first player

        Raises:
            ValueError: If scenario/character is invalid or not found
        """
        # Verify scenario version exists and scenario is published
        version = await self.db.scalar(
            select(ScenarioVersion).where(ScenarioVersion.id == scenario_version_id)
        )
        if not version:
            raise ValueError("Scenario version not found")

        scenario = await self.db.scalar(
            select(Scenario).where(Scenario.id == version.scenario_id)
        )
        if not scenario or scenario.status != ScenarioStatus.PUBLISHED:
            raise ValueError("Scenario must be published before creating a room")

        if max_players == 1 and not character_id:
            raise ValueError("Character ID is required for single player games")

        # Add host as first player
        host_player_character_id = None
        initial_status = RoomPlayerStatus.APPROVED
        if max_players == 1:
            # Verify character exists and belongs to user
            character = await self.db.scalar(
                select(Character).where(
                    Character.id == character_id, Character.user_id == host_id
                )
            )
            if not character:
                raise ValueError("Character not found or not owned by user")
            host_player_character_id = character_id
            initial_status = RoomPlayerStatus.READY

        room = Room(
            id=uuid.uuid4(),
            host_id=host_id,
            scenario_version_id=scenario_version_id,
            name=name,
            status=RoomStatus.WAITING,
            max_players=max_players,
        )
        self.db.add(room)
        await self.db.flush()

        host_player = RoomPlayer(
            id=uuid.uuid4(),
            room_id=room.id,
            user_id=host_id,
            status=initial_status,
            is_host=True,
            character_id=host_player_character_id,
        )
        self.db.add(host_player)
        await self.db.commit()

        # Reload with relationships
        return await self._get_room_with_relations(room.id)

    async def list_rooms(self, status: RoomStatus | None = None) -> list[Room]:
        """List available rooms.

        Args:
            status: Optional status filter

        Returns:
            List of rooms
        """
        query = select(Room).options(
            selectinload(Room.players).selectinload(RoomPlayer.user),
            selectinload(Room.host),
            selectinload(Room.scenario_version).selectinload(ScenarioVersion.scenario),
        )

        if status:
            query = query.where(Room.status == status)

        # Only show waiting and active rooms by default
        if not status:
            query = query.where(Room.status.in_([RoomStatus.WAITING, RoomStatus.ACTIVE]))

        query = query.order_by(Room.created_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_room(self, room_id: uuid.UUID) -> Room:
        """Get room by ID with full details.

        Args:
            room_id: Room ID

        Returns:
            Room with players and scenario

        Raises:
            ValueError: If room not found
        """
        room = await self._get_room_with_relations(room_id)
        if not room:
            raise ValueError("Room not found")
        return room

    async def join_room(self, room_id: uuid.UUID, user_id: uuid.UUID) -> RoomPlayer:
        """Request to join a room.

        Args:
            room_id: Room to join
            user_id: User requesting to join

        Returns:
            Created room player entry

        Raises:
            ValueError: If room not found, full, or user already in room
        """
        room = await self._get_room_with_relations(room_id)
        if not room:
            raise ValueError("Room not found")

        if room.status != RoomStatus.WAITING:
            raise ValueError("Room is not accepting players")

        # Check if user already in room
        existing = await self.db.execute(
            select(RoomPlayer).where(
                RoomPlayer.room_id == room_id,
                RoomPlayer.user_id == user_id,
            )
        )
        if existing.scalar_one_or_none():
            raise ValueError("Already in this room")

        # Check if room is full (count non-declined players)
        active_count = sum(
            1 for p in room.players if p.status != RoomPlayerStatus.DECLINED
        )
        if active_count >= room.max_players:
            raise ValueError("Room is full")

        player = RoomPlayer(
            id=uuid.uuid4(),
            room_id=room_id,
            user_id=user_id,
            status=RoomPlayerStatus.PENDING,
            is_host=False,
        )
        self.db.add(player)
        await self.db.commit()
        await self.db.refresh(player)

        logger.info(
            "Player joined room",
            user_id=str(user_id),
            room_id=str(room_id),
        )
        return player

    async def approve_player(
        self, room_id: uuid.UUID, player_id: uuid.UUID, host_id: uuid.UUID
    ) -> RoomPlayer:
        """Approve a player's join request (host only).

        Args:
            room_id: Room ID
            player_id: RoomPlayer ID to approve
            host_id: ID of the user performing the action (must be host)

        Returns:
            Updated room player

        Raises:
            ValueError: If not host, player not found, or invalid state
        """
        room = await self._get_room_with_relations(room_id)
        if not room:
            raise ValueError("Room not found")

        if room.host_id != host_id:
            raise ValueError("Only the host can approve players")

        player = await self._get_room_player(player_id, room_id)
        if not player:
            raise ValueError("Player not found in this room")

        if player.status != RoomPlayerStatus.PENDING:
            raise ValueError("Player is not in pending status")

        player.status = RoomPlayerStatus.APPROVED
        await self.db.commit()
        await self.db.refresh(player)
        return player

    async def decline_player(
        self, room_id: uuid.UUID, player_id: uuid.UUID, host_id: uuid.UUID
    ) -> RoomPlayer:
        """Decline a player's join request (host only).

        Args:
            room_id: Room ID
            player_id: RoomPlayer ID to decline
            host_id: ID of the user performing the action (must be host)

        Returns:
            Updated room player

        Raises:
            ValueError: If not host, player not found, or invalid state
        """
        room = await self._get_room_with_relations(room_id)
        if not room:
            raise ValueError("Room not found")

        if room.host_id != host_id:
            raise ValueError("Only the host can decline players")

        player = await self._get_room_player(player_id, room_id)
        if not player:
            raise ValueError("Player not found in this room")

        if player.status not in (RoomPlayerStatus.PENDING, RoomPlayerStatus.APPROVED):
            raise ValueError("Player cannot be declined in current status")

        player.status = RoomPlayerStatus.DECLINED
        await self.db.commit()
        await self.db.refresh(player)
        return player

    async def toggle_ready(
        self,
        room_id: uuid.UUID,
        user_id: uuid.UUID,
        character_id: uuid.UUID | None,
        ready: bool,
    ) -> RoomPlayer:
        """Toggle player ready status.

        Args:
            room_id: Room ID
            user_id: User toggling ready
            character_id: Character to use
            ready: Whether player is ready

        Returns:
            Updated room player

        Raises:
            ValueError: If player not found, not approved, or character invalid
        """
        # Find the player in this room
        result = await self.db.execute(
            select(RoomPlayer).where(
                RoomPlayer.room_id == room_id,
                RoomPlayer.user_id == user_id,
            )
        )
        player = result.scalar_one_or_none()
        if not player:
            raise ValueError("Not a member of this room")

        if player.status not in (
            RoomPlayerStatus.APPROVED,
            RoomPlayerStatus.READY,
        ):
            raise ValueError("Must be approved to toggle ready status")

        if ready:
            if not character_id:
                raise ValueError("Character is required to set ready status")
            # Verify character exists and belongs to user
            char_result = await self.db.execute(
                select(Character).where(
                    Character.id == character_id,
                    Character.user_id == user_id,
                )
            )
            character = char_result.scalar_one_or_none()
            if not character:
                raise ValueError("Character not found or not owned by user")

            player.character_id = character_id
            player.status = RoomPlayerStatus.READY
        else:
            player.character_id = None
            player.status = RoomPlayerStatus.APPROVED

        await self.db.commit()
        await self.db.refresh(player)
        return player

    async def start_game(self, room_id: uuid.UUID, host_id: uuid.UUID) -> GameSession:
        """Start the game (host only, all players must be ready).

        Args:
            room_id: Room ID
            host_id: ID of user starting the game (must be host)

        Returns:
            Game session object

        Raises:
            ValueError: If not host, not all ready, or room not in waiting status
        """
        room = await self._get_room_with_relations(room_id)
        if not room:
            raise ValueError("Room not found")

        if room.host_id != host_id:
            raise ValueError("Only the host can start the game")

        if room.status != RoomStatus.WAITING:
            raise ValueError("Room is not in waiting status")

        # Check all non-declined players are ready
        active_players = [
            p for p in room.players if p.status != RoomPlayerStatus.DECLINED
        ]

        if len(active_players) < 1:
            raise ValueError("Need at least 1 player to start")

        not_ready = [p for p in active_players if p.status != RoomPlayerStatus.READY]
        if not_ready:
            raise ValueError("Not all players are ready")

        # Update room status
        room.status = RoomStatus.ACTIVE
        room.started_at = datetime.now(UTC)

        # Build initial world state from scenario version
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

        # Create a game session record
        game_session = GameSession(
            id=uuid.uuid4(),
            room_id=room.id,
            world_state=initial_world_state,
        )
        self.db.add(game_session)

        await self.db.commit()
        await self.db.refresh(game_session)

        logger.info(
            "Game started",
            room_id=str(room_id),
            host_id=str(host_id),
        )

        # Generate opening DM message asynchronously to not block the response
        asyncio.create_task(
            self._generate_opening_message(
                game_session.id,
                str(room_id),
                content,
                initial_world_state,
                active_players,
            )
        )

        return game_session

    async def _generate_opening_message(
        self,
        session_id: uuid.UUID,
        room_id: str,
        scenario_content: dict,
        world_state: dict,
        active_players: list,
    ) -> None:
        """Generate and broadcast opening DM message in background."""
        import json
        try:
            # Use a fresh DB session for background task
            async with get_db_context() as db:
                from src.core.redis import get_redis_service

                session_service = SessionService(db)
                ai_service = AIService()
                redis = await get_redis_service()

                # Build player info for the AI
                players = []
                for rp in active_players:
                    if rp.character:
                        players.append({
                            "id": str(rp.user_id),
                            "name": rp.user.name if rp.user else "Unknown",
                            "character": {
                                "name": rp.character.name,
                                "class": rp.character.character_class,
                                "race": rp.character.race,
                                "level": rp.character.level,
                            },
                        })

                # Generate opening narration with streaming
                opening_prompt = "[SESSION START] Это начало приключения. Опиши начальную сцену, представь игроков и их персонажей, опиши атмосферу и локацию. Погрузи их в мир и дай понять что происходит. Сделай это живым и увлекательным вступлением. Не спрашивай что они делают - просто установи сцену."

                dm_message_id = uuid.uuid4()
                full_response = ""

                # Stream the opening message
                async for chunk in ai_service.stream_dm_response(
                    player_message=opening_prompt,
                    scenario_content=scenario_content,
                    world_state=world_state,
                    players=players,
                    conversation_history=[],
                ):
                    full_response += chunk
                    # Broadcast chunk to all players
                    chunk_msg = {
                        "type": "dm_response_chunk",
                        "chunk": chunk,
                        "message_id": str(dm_message_id),
                    }
                    await redis.publish(f"room:{room_id}", json.dumps(chunk_msg))

                # Send end marker
                end_msg = {
                    "type": "dm_response_end",
                    "message_id": str(dm_message_id),
                    "full_content": full_response,
                }
                await redis.publish(f"room:{room_id}", json.dumps(end_msg))

                # Save the opening message
                await session_service.add_dm_message(
                    session_id=session_id,
                    content=full_response,
                )

                logger.info(
                    "Opening DM message generated",
                    session_id=str(session_id),
                )

        except Exception as e:
            logger.error(
                "Failed to generate opening message",
                session_id=str(session_id),
                error=str(e),
            )

    async def _get_room_with_relations(self, room_id: uuid.UUID) -> Room | None:
        """Get room with all relationships loaded."""
        result = await self.db.execute(
            select(Room)
            .where(Room.id == room_id)
            .options(
                selectinload(Room.players).selectinload(RoomPlayer.user),
                selectinload(Room.players).selectinload(RoomPlayer.character),
                selectinload(Room.host),
                selectinload(Room.scenario_version).selectinload(ScenarioVersion.scenario),
            )
        )
        return result.scalar_one_or_none()

    async def _get_room_player(
        self, player_id: uuid.UUID, room_id: uuid.UUID
    ) -> RoomPlayer | None:
        """Get a room player by ID."""
        result = await self.db.execute(
            select(RoomPlayer).where(
                RoomPlayer.id == player_id,
                RoomPlayer.room_id == room_id,
            )
        )
        return result.scalar_one_or_none()
