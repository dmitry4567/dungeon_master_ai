"""Initial migration with users table

Revision ID: 001_initial
Revises:
Create Date: 2026-02-21

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=True),
        sa.Column("apple_user_id", sa.String(length=255), nullable=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
        sa.UniqueConstraint("apple_user_id"),
    )
    op.create_index("idx_users_email", "users", ["email"], unique=False)
    op.create_index("idx_users_apple_user_id", "users", ["apple_user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("idx_users_apple_user_id", table_name="users")
    op.drop_index("idx_users_email", table_name="users")
    op.drop_table("users")
