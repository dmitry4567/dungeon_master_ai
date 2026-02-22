"""Scenario and ScenarioVersion SQLAlchemy models."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.user import User


class ScenarioStatus(StrEnum):
    """Scenario status enum."""

    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class Scenario(Base):
    """Scenario model - template for game adventures."""

    __tablename__ = "scenarios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    creator_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )
    status: Mapped[ScenarioStatus] = mapped_column(
        SQLEnum(ScenarioStatus, name="scenario_status"),
        nullable=False,
        default=ScenarioStatus.DRAFT,
        index=True,
    )
    current_version_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("scenario_versions.id", ondelete="SET NULL"),
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
    creator: Mapped[User] = relationship(back_populates="scenarios")
    versions: Mapped[list[ScenarioVersion]] = relationship(
        "ScenarioVersion",
        back_populates="scenario",
        foreign_keys="ScenarioVersion.scenario_id",
        cascade="all, delete-orphan",
        order_by="ScenarioVersion.version",
    )
    current_version: Mapped[ScenarioVersion | None] = relationship(
        "ScenarioVersion",
        foreign_keys=[current_version_id],
        post_update=True,
    )

    __table_args__ = (
        Index("idx_scenarios_creator_id", "creator_id"),
        Index("idx_scenarios_status", "status"),
    )

    def __repr__(self) -> str:
        return f"<Scenario(id={self.id}, title={self.title}, status={self.status})>"


class ScenarioVersion(Base):
    """Immutable snapshot of scenario content at a point in time."""

    __tablename__ = "scenario_versions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    scenario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("scenarios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    content: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
    )
    user_prompt: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    validation_errors: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    # Relationships
    scenario: Mapped[Scenario] = relationship(
        "Scenario",
        back_populates="versions",
        foreign_keys=[scenario_id],
    )

    __table_args__ = (
        Index("idx_scenario_versions_scenario_id", "scenario_id"),
        Index(
            "idx_scenario_versions_scenario_version",
            "scenario_id",
            "version",
            unique=True,
        ),
    )

    def __repr__(self) -> str:
        return f"<ScenarioVersion(id={self.id}, scenario_id={self.scenario_id}, version={self.version})>"
