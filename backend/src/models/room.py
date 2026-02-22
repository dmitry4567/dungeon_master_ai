"""Room and RoomPlayer SQLAlchemy models."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.character import Character
    from src.models.scenario import ScenarioVersion
    from src.models.user import User


class RoomStatus(StrEnum):
    """Room status enum."""

    WAITING = "waiting"
    ACTIVE = "active"
    COMPLETED = "completed"


class RoomPlayerStatus(StrEnum):
    """Room player status enum."""

    PENDING = "pending"
    APPROVED = "approved"
    READY = "ready"
    DECLINED = "declined"


class Room(Base):
    """Game room / lobby model."""

    __tablename__ = "rooms"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    host_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    scenario_version_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("scenario_versions.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    status: Mapped[RoomStatus] = mapped_column(
        SQLEnum(RoomStatus, name="room_status"),
        nullable=False,
        default=RoomStatus.WAITING,
    )
    max_players: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=5,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    host: Mapped[User] = relationship(foreign_keys=[host_id])
    scenario_version: Mapped[ScenarioVersion] = relationship(foreign_keys=[scenario_version_id])
    players: Mapped[list[RoomPlayer]] = relationship(
        back_populates="room",
        cascade="all, delete-orphan",
        order_by="RoomPlayer.joined_at",
    )

    __table_args__ = (
        Index("idx_rooms_host_id", "host_id"),
        Index("idx_rooms_status", "status"),
    )

    def __repr__(self) -> str:
        return f"<Room(id={self.id}, name={self.name}, status={self.status})>"


class RoomPlayer(Base):
    """Association between room and participating players."""

    __tablename__ = "room_players"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    character_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("characters.id", ondelete="SET NULL"),
        nullable=True,
    )
    status: Mapped[RoomPlayerStatus] = mapped_column(
        SQLEnum(RoomPlayerStatus, name="room_player_status"),
        nullable=False,
        default=RoomPlayerStatus.PENDING,
    )
    is_host: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    # Relationships
    room: Mapped[Room] = relationship(back_populates="players")
    user: Mapped[User] = relationship(foreign_keys=[user_id])
    character: Mapped[Character | None] = relationship(foreign_keys=[character_id])

    __table_args__ = (
        UniqueConstraint("room_id", "user_id", name="uq_room_players_room_user"),
        Index("idx_room_players_room_id", "room_id"),
        Index("idx_room_players_user_id", "user_id"),
    )

    def __repr__(self) -> str:
        return f"<RoomPlayer(id={self.id}, room_id={self.room_id}, user_id={self.user_id}, status={self.status})>"
