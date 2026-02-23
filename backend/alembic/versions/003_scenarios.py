"""Add scenarios and scenario_versions tables

Revision ID: 003_scenarios
Revises: 002_characters
Create Date: 2026-02-22

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "003_scenarios"
down_revision: Union[str, None] = "002_characters"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create scenario_status enum type
    op.execute("CREATE TYPE scenario_status AS ENUM ('draft', 'published', 'archived')")

    # Create scenarios table
    op.create_table(
        "scenarios",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("creator_id", sa.UUID(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column(
            "status",
            postgresql.ENUM("draft", "published", "archived", name="scenario_status"),
            nullable=False,
            server_default="draft",
        ),
        sa.Column("current_version_id", sa.UUID(), nullable=True),
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
        sa.ForeignKeyConstraint(
            ["creator_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("idx_scenarios_creator_id", "scenarios", ["creator_id"], unique=False)
    op.create_index("idx_scenarios_status", "scenarios", ["status"], unique=False)

    # Create scenario_versions table
    op.create_table(
        "scenario_versions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("scenario_id", sa.UUID(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("content", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("user_prompt", sa.Text(), nullable=False),
        sa.Column("validation_errors", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["scenario_id"],
            ["scenarios.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "idx_scenario_versions_scenario_id",
        "scenario_versions",
        ["scenario_id"],
        unique=False,
    )
    op.create_index(
        "idx_scenario_versions_scenario_version",
        "scenario_versions",
        ["scenario_id", "version"],
        unique=True,
    )

    # Add foreign key from scenarios to scenario_versions (circular reference)
    op.create_foreign_key(
        "fk_scenarios_current_version_id",
        "scenarios",
        "scenario_versions",
        ["current_version_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    # Drop foreign key from scenarios
    op.drop_constraint("fk_scenarios_current_version_id", "scenarios", type_="foreignkey")

    # Drop scenario_versions table
    op.drop_index("idx_scenario_versions_scenario_version", table_name="scenario_versions")
    op.drop_index("idx_scenario_versions_scenario_id", table_name="scenario_versions")
    op.drop_table("scenario_versions")

    # Drop scenarios table
    op.drop_index("idx_scenarios_status", table_name="scenarios")
    op.drop_index("idx_scenarios_creator_id", table_name="scenarios")
    op.drop_table("scenarios")

    # Drop enum type
    op.execute("DROP TYPE scenario_status")
