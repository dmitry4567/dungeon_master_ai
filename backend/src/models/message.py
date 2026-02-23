"""SessionMessage SQLAlchemy model."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.session import GameSession
    from src.models.user import User


class MessageRole(StrEnum):
    """Message role enum."""

    PLAYER = "player"
    DM = "dm"
    SYSTEM = "system"


class SessionMessage(Base):
    """Individual message in a game session."""

    __tablename__ = "session_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("game_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    author_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    role: Mapped[MessageRole] = mapped_column(
        SQLEnum(MessageRole, name="message_role"),
        nullable=False,
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    dice_result: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    state_delta: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    # Relationships
    session: Mapped[GameSession] = relationship(back_populates="messages")
    author: Mapped[User | None] = relationship(foreign_keys=[author_id])

    __table_args__ = (
        Index("idx_session_messages_session_id", "session_id"),
        Index("idx_session_messages_created_at", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<SessionMessage(id={self.id}, role={self.role}, session_id={self.session_id})>"
