"""User profile routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from src.api.dependencies import CurrentUser, DbSession
from src.schemas.common import ErrorResponse
from src.schemas.user import UserResponse, UserUpdate
from src.services.user_service import UserNotFoundError, UserService

router = APIRouter(prefix="/users", tags=["Users"])


@router.get(
    "/me",
    response_model=UserResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Not authenticated"},
    },
)
async def get_current_user_profile(
    current_user: CurrentUser,
) -> UserResponse:
    """Get current authenticated user's profile."""
    return UserResponse.model_validate(current_user)


@router.patch(
    "/me",
    response_model=UserResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Not authenticated"},
        400: {"model": ErrorResponse, "description": "Validation error"},
    },
)
async def update_current_user_profile(
    data: UserUpdate,
    current_user: CurrentUser,
    db: DbSession,
) -> UserResponse:
    """Update current authenticated user's profile."""
    user_service = UserService(db)

    try:
        updated_user = await user_service.update(current_user.id, data)
        return UserResponse.model_validate(updated_user)
    except UserNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": e.code, "message": e.message},
        )
