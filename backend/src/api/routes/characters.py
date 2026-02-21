"""Character API routes."""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from src.api.dependencies import CurrentUser, DbSession
from src.schemas.character import (
    CharacterCreate,
    CharacterResponse,
    CharacterUpdate,
)
from src.services.character_service import (
    CharacterNotFoundError,
    CharacterService,
    CharacterValidationError,
)

router = APIRouter(prefix="/characters", tags=["characters"])


@router.get("", response_model=list[CharacterResponse])
async def list_characters(
    current_user: CurrentUser,
    db: DbSession,
) -> list[CharacterResponse]:
    """List all characters for the current user."""
    service = CharacterService(db)
    characters = await service.get_all_for_user(current_user.id)
    return [CharacterResponse.model_validate(c) for c in characters]


@router.post("", response_model=CharacterResponse, status_code=status.HTTP_201_CREATED)
async def create_character(
    data: CharacterCreate,
    current_user: CurrentUser,
    db: DbSession,
) -> CharacterResponse:
    """Create a new character."""
    service = CharacterService(db)

    try:
        character = await service.create(current_user.id, data)
    except CharacterValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "validation_error",
                "message": "D&D 5e validation failed",
                "errors": e.errors,
            },
        )

    return CharacterResponse.model_validate(character)


@router.get("/{character_id}", response_model=CharacterResponse)
async def get_character(
    character_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> CharacterResponse:
    """Get a character by ID."""
    service = CharacterService(db)

    try:
        character = await service.get_by_id(character_id, current_user.id)
    except CharacterNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "not_found",
                "message": "Character not found",
            },
        )

    return CharacterResponse.model_validate(character)


@router.patch("/{character_id}", response_model=CharacterResponse)
async def update_character(
    character_id: UUID,
    data: CharacterUpdate,
    current_user: CurrentUser,
    db: DbSession,
) -> CharacterResponse:
    """Update a character."""
    service = CharacterService(db)

    try:
        character = await service.update(character_id, current_user.id, data)
    except CharacterNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "not_found",
                "message": "Character not found",
            },
        )

    return CharacterResponse.model_validate(character)


@router.delete("/{character_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_character(
    character_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> None:
    """Delete a character."""
    service = CharacterService(db)

    try:
        await service.delete(character_id, current_user.id)
    except CharacterNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "not_found",
                "message": "Character not found",
            },
        )
