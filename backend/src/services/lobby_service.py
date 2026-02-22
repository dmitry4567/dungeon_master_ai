"""Lobby service for managing game rooms and player coordination."""
import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.models.character import Character
from src.models.room import Room, RoomPlayer, RoomPlayerStatus, RoomStatus
from src.models.scenario import Scenario, ScenarioStatus, ScenarioVersion

logger = logging.getLogger(__name__)


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
    ) -> Room:
        """Create a new game room.

        Args:
            host_id: ID of the user creating the room
            name: Room display name
            scenario_version_id: ID of the scenario version to use
            max_players: Maximum number of players (2-5)

        Returns:
            Created room with host as first player

        Raises:
            ValueError: If scenario version not found
        """
        # Verify scenario version exists and scenario is published
        result = await self.db.execute(
            select(ScenarioVersion).where(ScenarioVersion.id == scenario_version_id)
        )
        version = result.scalar_one_or_none()
        if not version:
            raise ValueError("Scenario version not found")

        scenario_result = await self.db.execute(
            select(Scenario).where(Scenario.id == version.scenario_id)
        )
        scenario = scenario_result.scalar_one_or_none()
        if not scenario or scenario.status != ScenarioStatus.PUBLISHED:
            raise ValueError("Scenario must be published before creating a room")

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

        # Add host as first player (auto-approved)
        host_player = RoomPlayer(
            id=uuid.uuid4(),
            room_id=room.id,
            user_id=host_id,
            status=RoomPlayerStatus.APPROVED,
            is_host=True,
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
            selectinload(Room.scenario_version),
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
            f"User {user_id} joined room {room_id}",
            extra={"user_id": str(user_id), "room_id": str(room_id)},
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
        character_id: uuid.UUID,
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

    async def start_game(self, room_id: uuid.UUID, host_id: uuid.UUID) -> dict:
        """Start the game (host only, all players must be ready).

        Args:
            room_id: Room ID
            host_id: ID of user starting the game (must be host)

        Returns:
            Game session data dict

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

        if len(active_players) < 2:
            raise ValueError("Need at least 2 players to start")

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

        # Create a game session record (simplified - full GameSession model in Phase 7)
        session_id = uuid.uuid4()
        game_session = {
            "id": str(session_id),
            "room_id": str(room.id),
            "world_state": initial_world_state,
            "started_at": room.started_at.isoformat(),
        }

        await self.db.commit()

        logger.info(
            f"Game started for room {room_id}",
            extra={"room_id": str(room_id), "host_id": str(host_id)},
        )

        return game_session

    async def _get_room_with_relations(self, room_id: uuid.UUID) -> Room | None:
        """Get room with all relationships loaded."""
        result = await self.db.execute(
            select(Room)
            .where(Room.id == room_id)
            .options(
                selectinload(Room.players).selectinload(RoomPlayer.user),
                selectinload(Room.players).selectinload(RoomPlayer.character),
                selectinload(Room.host),
                selectinload(Room.scenario_version),
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
