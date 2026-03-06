"""Scenario service for managing scenario generation and versioning."""
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.models.scenario import Scenario, ScenarioStatus, ScenarioVersion
from src.services.ai_service import AIService
from src.core.logging import get_logger
# from src.services.ai_service_openrouter import AIServiceOpenRouter

logger = get_logger(__name__)


class ScenarioService:
    """Service for scenario management."""

    def __init__(self, db: AsyncSession) -> None:
        """Initialize scenario service."""
        self.db = db
        # self.ai_service = AIService()
        self.ai_service = AIService()

    async def generate_scenario(
        self, user_id: uuid.UUID, description: str
    ) -> Scenario:
        """
        Generate a new scenario from user description.

        Args:
            user_id: ID of user creating the scenario
            description: Natural language description

        Returns:
            Created scenario with initial version
        """
        logger.info("Starting scenario generation for user=%s, description=%s", str(user_id), description[:100])
        
        # Generate scenario content using AI
        logger.info("Calling AI service to generate scenario")
        title, content = await self.ai_service.generate_scenario(description)
        logger.info("AI scenario generation complete: title=%s, content_keys=%s", title, list(content.keys()))

        # Validate the generated content
        logger.info("Validating scenario content")
        validation_errors = self._validate_scenario_content(content)
        if validation_errors:
            logger.warning("Validation errors found: %s", validation_errors)

        # Create scenario
        logger.info("Creating scenario record in database")
        scenario = Scenario(
            id=uuid.uuid4(),
            creator_id=user_id,
            title=title,
            status=ScenarioStatus.DRAFT,
        )
        self.db.add(scenario)
        await self.db.flush()
        logger.info("Scenario record created: scenario_id=%s", str(scenario.id))

        # Create initial version
        logger.info("Creating initial scenario version")
        version = ScenarioVersion(
            id=uuid.uuid4(),
            scenario_id=scenario.id,
            version=1,
            content=content,
            user_prompt=description,
            validation_errors=validation_errors if validation_errors else None,
        )
        self.db.add(version)
        await self.db.flush()
        logger.info("Scenario version created: version_id=%s", str(version.id))

        # Set current version
        scenario.current_version_id = version.id
        await self.db.commit()
        await self.db.refresh(scenario, ["current_version"])

        logger.info(
            "Scenario created: scenario_id=%s, version=%s, user_id=%s",
            str(scenario.id),
            version.version,
            str(user_id),
        )

        return scenario

    async def refine_scenario(
        self, scenario_id: uuid.UUID, user_id: uuid.UUID, refinement_prompt: str
    ) -> Scenario:
        """
        Refine an existing scenario, creating a new version.

        Args:
            scenario_id: ID of scenario to refine
            user_id: ID of user requesting refinement
            refinement_prompt: Refinement instructions

        Returns:
            Updated scenario with new version

        Raises:
            ValueError: If scenario not found or user not authorized
        """
        # Fetch scenario with current version
        result = await self.db.execute(
            select(Scenario)
            .where(Scenario.id == scenario_id)
            .options(selectinload(Scenario.current_version))
        )
        scenario = result.scalar_one_or_none()

        if not scenario:
            raise ValueError("Scenario not found")

        if scenario.creator_id != user_id:
            raise ValueError("Not authorized to modify this scenario")

        if not scenario.current_version:
            raise ValueError("Scenario has no current version")

        # Get current version details
        current_version = scenario.current_version
        current_title = scenario.title
        current_content = current_version.content

        # Refine using AI
        new_title, new_content = await self.ai_service.refine_scenario(
            current_title, current_content, refinement_prompt
        )

        # Validate new content
        validation_errors = self._validate_scenario_content(new_content)

        # Get next version number
        result = await self.db.execute(
            select(ScenarioVersion)
            .where(ScenarioVersion.scenario_id == scenario_id)
            .order_by(ScenarioVersion.version.desc())
        )
        latest_version = result.first()
        next_version = (latest_version[0].version + 1) if latest_version else 1

        # Create new version
        new_version = ScenarioVersion(
            id=uuid.uuid4(),
            scenario_id=scenario.id,
            version=next_version,
            content=new_content,
            user_prompt=refinement_prompt,
            validation_errors=validation_errors if validation_errors else None,
        )
        self.db.add(new_version)
        await self.db.flush()

        # Update scenario
        scenario.title = new_title
        scenario.current_version_id = new_version.id
        await self.db.commit()
        await self.db.refresh(scenario, ["current_version"])

        logger.info(
            "Scenario refined",
            scenario_id=str(scenario.id),
            version=new_version.version,
            user_id=str(user_id),
        )

        return scenario

    async def get_scenario(
        self, scenario_id: uuid.UUID, user_id: uuid.UUID
    ) -> Scenario:
        """
        Get scenario by ID.

        Args:
            scenario_id: Scenario ID
            user_id: User ID (for authorization)

        Returns:
            Scenario with current version

        Raises:
            ValueError: If scenario not found or unauthorized
        """
        result = await self.db.execute(
            select(Scenario)
            .where(Scenario.id == scenario_id)
            .options(selectinload(Scenario.current_version))
        )
        scenario = result.scalar_one_or_none()

        if not scenario:
            raise ValueError("Scenario not found")

        if scenario.creator_id != user_id:
            raise ValueError("Not authorized to view this scenario")

        return scenario

    async def list_scenarios(
        self, user_id: uuid.UUID, status: ScenarioStatus | None = None
    ) -> list[Scenario]:
        """
        List user's scenarios.

        Args:
            user_id: User ID
            status: Optional status filter

        Returns:
            List of scenarios
        """
        query = select(Scenario).where(Scenario.creator_id == user_id)

        if status:
            query = query.where(Scenario.status == status)

        query = query.order_by(Scenario.created_at.desc())

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_versions(
        self, scenario_id: uuid.UUID, user_id: uuid.UUID
    ) -> list[ScenarioVersion]:
        """
        List all versions of a scenario.

        Args:
            scenario_id: Scenario ID
            user_id: User ID (for authorization)

        Returns:
            List of scenario versions

        Raises:
            ValueError: If scenario not found or unauthorized
        """
        # Check authorization
        result = await self.db.execute(
            select(Scenario).where(Scenario.id == scenario_id)
        )
        scenario = result.scalar_one_or_none()

        if not scenario:
            raise ValueError("Scenario not found")

        if scenario.creator_id != user_id:
            raise ValueError("Not authorized to view this scenario")

        # Get versions
        result = await self.db.execute(
            select(ScenarioVersion)
            .where(ScenarioVersion.scenario_id == scenario_id)
            .order_by(ScenarioVersion.version.desc())
        )
        return list(result.scalars().all())

    async def restore_version(
        self, scenario_id: uuid.UUID, version_id: uuid.UUID, user_id: uuid.UUID
    ) -> Scenario:
        """
        Restore a previous version as current.

        Args:
            scenario_id: Scenario ID
            version_id: Version ID to restore
            user_id: User ID (for authorization)

        Returns:
            Updated scenario

        Raises:
            ValueError: If scenario/version not found or unauthorized
        """
        # Check authorization
        result = await self.db.execute(
            select(Scenario).where(Scenario.id == scenario_id)
        )
        scenario = result.scalar_one_or_none()

        if not scenario:
            raise ValueError("Scenario not found")

        if scenario.creator_id != user_id:
            raise ValueError("Not authorized to modify this scenario")

        # Verify version exists and belongs to scenario
        result = await self.db.execute(
            select(ScenarioVersion).where(
                ScenarioVersion.id == version_id,
                ScenarioVersion.scenario_id == scenario_id,
            )
        )
        version = result.scalar_one_or_none()

        if not version:
            raise ValueError("Version not found")

        # Update current version
        scenario.current_version_id = version_id
        await self.db.commit()
        await self.db.refresh(scenario, ["current_version"])

        logger.info(
            "Scenario restored",
            scenario_id=str(scenario.id),
            version=version.version,
            user_id=str(user_id),
        )

        return scenario

    async def publish_scenario(
        self, scenario_id: uuid.UUID, user_id: uuid.UUID
    ) -> Scenario:
        """Publish a draft scenario (draft → published).

        Raises:
            ValueError: If not found, not authorized, or not in draft status
        """
        result = await self.db.execute(
            select(Scenario)
            .where(Scenario.id == scenario_id)
            .options(selectinload(Scenario.current_version))
        )
        scenario = result.scalar_one_or_none()

        if not scenario:
            raise ValueError("Scenario not found")
        if scenario.creator_id != user_id:
            raise ValueError("Not authorized to modify this scenario")
        if scenario.status != ScenarioStatus.DRAFT:
            raise ValueError("Only draft scenarios can be published")
        if not scenario.current_version_id:
            raise ValueError("Scenario has no version to publish")

        scenario.status = ScenarioStatus.PUBLISHED
        await self.db.commit()
        await self.db.refresh(scenario, ["current_version"])

        logger.info(
            "Scenario published: scenario_id=%s, user_id=%s",
            str(scenario.id),
            str(user_id),
        )
        return scenario

    def _validate_scenario_content(self, content: dict[str, Any]) -> list[str] | None:
        """
        Validate scenario content structure and logic.

        Args:
            content: Scenario content to validate

        Returns:
            List of validation errors, or None if valid
        """
        errors = []

        # Check required fields
        required_fields = [
            "tone",
            "difficulty",
            "players_min",
            "players_max",
            "world_lore",
            "acts",
            "npcs",
            "locations",
        ]
        for field in required_fields:
            if field not in content:
                errors.append(f"Missing required field: {field}")

        # Validate flags if present (optional field)
        if "flags" in content:
            flag_ids = set()
            for i, flag in enumerate(content["flags"]):
                if "id" not in flag:
                    errors.append(f"Flag {i} missing 'id' field")
                elif flag["id"] in flag_ids:
                    errors.append(f"Duplicate flag ID: {flag['id']}")
                else:
                    flag_ids.add(flag["id"])
                if "name" not in flag:
                    errors.append(f"Flag {flag.get('id', i)} missing 'name' field")
                if "description" not in flag:
                    errors.append(f"Flag {flag.get('id', i)} missing 'description' field")

        # Skip remaining validation if required fields are missing
        if errors:
            return errors


        # Validate acts
        if "acts" in content:
            if not content["acts"]:
                errors.append("Scenario must have at least one act")
            else:
                act_ids = set()
                for i, act in enumerate(content["acts"]):
                    if "id" not in act:
                        errors.append(f"Act {i} missing 'id' field")
                    elif act["id"] in act_ids:
                        errors.append(f"Duplicate act ID: {act['id']}")
                    else:
                        act_ids.add(act["id"])

                    if "scenes" not in act or not act["scenes"]:
                        errors.append(f"Act {act.get('id', i)} must have at least one scene")

        # Validate NPCs
        if "npcs" in content:
            npc_ids = set()
            for i, npc in enumerate(content["npcs"]):
                if "id" not in npc:
                    errors.append(f"NPC {i} missing 'id' field")
                elif npc["id"] in npc_ids:
                    errors.append(f"Duplicate NPC ID: {npc['id']}")
                else:
                    npc_ids.add(npc["id"])

        # Validate locations
        if "locations" in content:
            loc_ids = set()
            for i, loc in enumerate(content["locations"]):
                if "id" not in loc:
                    errors.append(f"Location {i} missing 'id' field")
                elif loc["id"] in loc_ids:
                    errors.append(f"Duplicate location ID: {loc['id']}")
                else:
                    loc_ids.add(loc["id"])

        # Validate player counts
        if (
            "players_min" in content
            and "players_max" in content
            and content["players_min"] > content["players_max"]
        ):
            errors.append("players_min cannot exceed players_max")

        return errors if errors else None
