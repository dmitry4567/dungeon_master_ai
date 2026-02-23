"""Add rooms and room_players tables

Revision ID: 004_rooms
Revises: 003_scenarios
Create Date: 2026-02-22

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "004_rooms"
down_revision: Union[str, None] = "003_scenarios"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create enum types
    op.execute("CREATE TYPE room_status AS ENUM ('waiting', 'active', 'completed')")
    op.execute(
        "CREATE TYPE room_player_status AS ENUM ('pending', 'approved', 'ready', 'declined')"
    )

    # Create rooms table
    op.create_table(
        "rooms",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("host_id", sa.UUID(), nullable=False),
        sa.Column("scenario_version_id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column(
            "status",
            postgresql.ENUM("waiting", "active", "completed", name="room_status"),
            nullable=False,
            server_default="waiting",
        ),
        sa.Column("max_players", sa.Integer(), nullable=False, server_default="5"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["host_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["scenario_version_id"],
            ["scenario_versions.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("idx_rooms_host_id", "rooms", ["host_id"], unique=False)
    op.create_index("idx_rooms_status", "rooms", ["status"], unique=False)

    # Create room_players table
    op.create_table(
        "room_players",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("room_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("character_id", sa.UUID(), nullable=True),
        sa.Column(
            "status",
            postgresql.ENUM(
                "pending", "approved", "ready", "declined", name="room_player_status"
            ),
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "is_host", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["room_id"],
            ["rooms.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["character_id"],
            ["characters.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("room_id", "user_id", name="uq_room_players_room_user"),
    )
    op.create_index(
        "idx_room_players_room_id", "room_players", ["room_id"], unique=False
    )
    op.create_index(
        "idx_room_players_user_id", "room_players", ["user_id"], unique=False
    )


def downgrade() -> None:
    # Drop room_players table
    op.drop_index("idx_room_players_user_id", table_name="room_players")
    op.drop_index("idx_room_players_room_id", table_name="room_players")
    op.drop_table("room_players")

    # Drop rooms table
    op.drop_index("idx_rooms_status", table_name="rooms")
    op.drop_index("idx_rooms_host_id", table_name="rooms")
    op.drop_table("rooms")

    # Drop enum types
    op.execute("DROP TYPE room_player_status")
    op.execute("DROP TYPE room_status")
