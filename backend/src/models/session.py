"""GameSession SQLAlchemy model."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.room import Room
    from src.models.message import SessionMessage


class GameSession(Base):
    """Active game session with world state."""

    __tablename__ = "game_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("rooms.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    world_state: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    room: Mapped[Room] = relationship(foreign_keys=[room_id])
    messages: Mapped[list[SessionMessage]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SessionMessage.created_at",
    )

    __table_args__ = (Index("idx_game_sessions_room_id", "room_id", unique=True),)

    def __repr__(self) -> str:
        return f"<GameSession(id={self.id}, room_id={self.room_id})>"
