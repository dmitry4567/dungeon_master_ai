"""Create game_sessions and session_messages tables.

Revision ID: 005
Revises: 004
Create Date: 2026-02-23

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "005"
down_revision: str | None = "004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Create message_role enum
    message_role = postgresql.ENUM("player", "dm", "system", name="message_role")
    message_role.create(op.get_bind(), checkfirst=True)

    # Create game_sessions table
    op.create_table(
        "game_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "world_state", postgresql.JSONB(astext_type=sa.Text()), nullable=False
        ),
        sa.Column(
            "started_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["room_id"], ["rooms.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("room_id"),
    )
    op.create_index(
        "idx_game_sessions_room_id", "game_sessions", ["room_id"], unique=True
    )

    # Create session_messages table
    op.create_table(
        "session_messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("author_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "role",
            postgresql.ENUM("player", "dm", "system", name="message_role", create_type=False),
            nullable=False,
        ),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "dice_result", postgresql.JSONB(astext_type=sa.Text()), nullable=True
        ),
        sa.Column(
            "state_delta", postgresql.JSONB(astext_type=sa.Text()), nullable=True
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.ForeignKeyConstraint(
            ["session_id"], ["game_sessions.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["author_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "idx_session_messages_session_id", "session_messages", ["session_id"]
    )
    op.create_index(
        "idx_session_messages_created_at", "session_messages", ["created_at"]
    )


def downgrade() -> None:
    op.drop_index("idx_session_messages_created_at", table_name="session_messages")
    op.drop_index("idx_session_messages_session_id", table_name="session_messages")
    op.drop_table("session_messages")
    op.drop_index("idx_game_sessions_room_id", table_name="game_sessions")
    op.drop_table("game_sessions")

    # Drop the enum type
    sa.Enum(name="message_role").drop(op.get_bind(), checkfirst=True)
