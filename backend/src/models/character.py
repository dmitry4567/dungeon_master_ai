"""Character SQLAlchemy model."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.user import User


class Character(Base):
    """D&D 5e character model."""

    __tablename__ = "characters"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    # Note: 'class' is a reserved word, so we use character_class as column name
    character_class: Mapped[str] = mapped_column(
        "class",
        String(50),
        nullable=False,
    )
    race: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    level: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
    )
    ability_scores: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
    )
    backstory: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    user: Mapped[User] = relationship(back_populates="characters")

    __table_args__ = (Index("idx_characters_user_id", "user_id"),)

    def __repr__(self) -> str:
        return f"<Character(id={self.id}, name={self.name}, class={self.character_class}, race={self.race})>"
