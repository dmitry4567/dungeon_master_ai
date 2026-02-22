"""Scenario API routes."""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from src.api.dependencies import CurrentUser, DbSession
from src.models.scenario import ScenarioStatus
from src.schemas.scenario import (
    CreateScenarioRequest,
    RefineScenarioRequest,
    ScenarioResponse,
    ScenarioVersionSummary,
    ScenarioWithVersionResponse,
)
from src.services.scenario_service import ScenarioService

router = APIRouter(prefix="/scenarios", tags=["scenarios"])


@router.get("", response_model=list[ScenarioResponse])
async def list_scenarios(
    current_user: CurrentUser,
    db: DbSession,
    status: ScenarioStatus | None = Query(None, description="Filter by status"),
) -> list[ScenarioResponse]:
    """List all scenarios for the current user."""
    service = ScenarioService(db)
    scenarios = await service.list_scenarios(current_user.id, status)
    return [ScenarioResponse.model_validate(s) for s in scenarios]


@router.post(
    "", response_model=ScenarioWithVersionResponse, status_code=status.HTTP_201_CREATED
)
async def create_scenario(
    data: CreateScenarioRequest,
    current_user: CurrentUser,
    db: DbSession,
) -> ScenarioWithVersionResponse:
    """Generate a new scenario from description."""
    service = ScenarioService(db)

    try:
        scenario = await service.generate_scenario(current_user.id, data.description)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": "generation_failed",
                "message": str(e),
            },
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": "internal_error",
                "message": "Failed to generate scenario",
            },
        )

    return ScenarioWithVersionResponse.model_validate(scenario)


@router.get("/{scenario_id}", response_model=ScenarioWithVersionResponse)
async def get_scenario(
    scenario_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> ScenarioWithVersionResponse:
    """Get a scenario by ID with current version."""
    service = ScenarioService(db)

    try:
        scenario = await service.get_scenario(scenario_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "not_found",
                    "message": "Scenario not found",
                },
            )
        elif "not authorized" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "forbidden",
                    "message": "Not authorized to access this scenario",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "bad_request",
                "message": str(e),
            },
        )

    return ScenarioWithVersionResponse.model_validate(scenario)


@router.post("/{scenario_id}/refine", response_model=ScenarioWithVersionResponse)
async def refine_scenario(
    scenario_id: UUID,
    data: RefineScenarioRequest,
    current_user: CurrentUser,
    db: DbSession,
) -> ScenarioWithVersionResponse:
    """Refine an existing scenario with a follow-up prompt."""
    service = ScenarioService(db)

    try:
        scenario = await service.refine_scenario(
            scenario_id, current_user.id, data.prompt
        )
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "not_found",
                    "message": "Scenario not found",
                },
            )
        elif "not authorized" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "forbidden",
                    "message": "Not authorized to modify this scenario",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "bad_request",
                "message": str(e),
            },
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": "internal_error",
                "message": "Failed to refine scenario",
            },
        )

    return ScenarioWithVersionResponse.model_validate(scenario)


@router.get("/{scenario_id}/versions", response_model=list[ScenarioVersionSummary])
async def list_scenario_versions(
    scenario_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> list[ScenarioVersionSummary]:
    """List all versions of a scenario."""
    service = ScenarioService(db)

    try:
        versions = await service.list_versions(scenario_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "not_found",
                    "message": "Scenario not found",
                },
            )
        elif "not authorized" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "forbidden",
                    "message": "Not authorized to access this scenario",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "bad_request",
                "message": str(e),
            },
        )

    return [ScenarioVersionSummary.model_validate(v) for v in versions]


@router.post(
    "/{scenario_id}/versions/{version_id}/restore",
    response_model=ScenarioWithVersionResponse,
)
async def restore_scenario_version(
    scenario_id: UUID,
    version_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> ScenarioWithVersionResponse:
    """Restore a previous version as the current version."""
    service = ScenarioService(db)

    try:
        scenario = await service.restore_version(
            scenario_id, version_id, current_user.id
        )
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "not_found",
                    "message": "Scenario or version not found",
                },
            )
        elif "not authorized" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "forbidden",
                    "message": "Not authorized to modify this scenario",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "bad_request",
                "message": str(e),
            },
        )

    return ScenarioWithVersionResponse.model_validate(scenario)


@router.post("/{scenario_id}/publish", response_model=ScenarioWithVersionResponse)
async def publish_scenario(
    scenario_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> ScenarioWithVersionResponse:
    """Publish a draft scenario, making it available for room creation."""
    service = ScenarioService(db)

    try:
        scenario = await service.publish_scenario(scenario_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "not_found",
                    "message": "Scenario not found",
                },
            )
        elif "not authorized" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": "forbidden",
                    "message": "Not authorized to publish this scenario",
                },
            )
        elif "only draft" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": "invalid_status",
                    "message": "Only draft scenarios can be published",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "bad_request",
                "message": str(e),
            },
        )

    return ScenarioWithVersionResponse.model_validate(scenario)
