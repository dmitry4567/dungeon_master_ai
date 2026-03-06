"""Room API routes."""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from src.api.dependencies import CurrentUser, DbSession
from src.core.config import get_settings
from src.core.logging import get_logger
from src.models.room import Room, RoomStatus
from src.schemas.room import (
    CreateRoomRequest,
    GameSessionResponse,
    ReadyRequest,
    RoomPlayerResponse,
    RoomResponse,
    RoomSummaryResponse,
)
from src.schemas.voice import VoiceTokenResponse
from src.services.lobby_service import LobbyService
from src.services.voice_service import create_voice_token_response

logger = get_logger(__name__)

router = APIRouter(prefix="/rooms", tags=["rooms"])


def _build_room_response(room) -> RoomResponse:
    """Build a RoomResponse from a Room model with loaded relationships."""
    from src.schemas.character import AbilityScores, CharacterResponse

    players = []
    for p in room.players:
        character_data = None
        if p.character:
            character_data = CharacterResponse(
                id=p.character.id,
                name=p.character.name,
                character_class=p.character.character_class,
                race=p.character.race,
                level=p.character.level,
                ability_scores=AbilityScores(**p.character.ability_scores),
                backstory=p.character.backstory,
                created_at=p.character.created_at,
            )
        player_resp = RoomPlayerResponse(
            id=p.id,
            user_id=p.user_id,
            name=p.user.name if p.user else "Unknown",
            character=character_data,
            status=p.status.value if hasattr(p.status, "value") else p.status,
            is_host=p.is_host,
        )
        players.append(player_resp)

    scenario_data = None
    if room.scenario_version and room.scenario_version.scenario_id:
        from src.schemas.scenario import ScenarioResponse

        # Build a minimal scenario response from the version's parent
        scenario_data = ScenarioResponse(
            id=room.scenario_version.scenario_id,
            title=room.scenario_version.scenario.title
            if room.scenario_version.scenario
            else "Untitled",
            status="published",
            current_version_id=room.scenario_version.id,
            created_at=room.created_at,
        )

    return RoomResponse(
        id=room.id,
        name=room.name,
        scenario=scenario_data,
        status=room.status.value if hasattr(room.status, "value") else room.status,
        max_players=room.max_players,
        players=players,
        created_at=room.created_at,
    )


def _build_room_summary(room, current_user_id: UUID | None = None) -> RoomSummaryResponse:
    """Build a RoomSummaryResponse from a Room model."""
    active_players = [
        p for p in room.players
        if (p.status.value if hasattr(p.status, "value") else p.status) != "declined"
    ]
    scenario_title = "Unknown"
    if room.scenario_version and room.scenario_version.scenario:
        scenario_title = room.scenario_version.scenario.title

    is_current_user_player = False
    if current_user_id:
        is_current_user_player = any(p.user_id == current_user_id for p in active_players)

    return RoomSummaryResponse(
        id=room.id,
        name=room.name,
        scenario_title=scenario_title,
        host_name=room.host.name if room.host else "Unknown",
        player_count=len(active_players),
        max_players=room.max_players,
        status=room.status.value if hasattr(room.status, "value") else room.status,
        is_current_user_player=is_current_user_player,
    )


@router.get("", response_model=list[RoomSummaryResponse])
async def list_rooms(
    current_user: CurrentUser,
    db: DbSession,
    status: RoomStatus | None = Query(None, description="Filter by status"),
) -> list[RoomSummaryResponse]:
    """List available rooms."""
    service = LobbyService(db)
    rooms = await service.list_rooms(status)
    return [_build_room_summary(r, current_user.id) for r in rooms]


@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    data: CreateRoomRequest,
    current_user: CurrentUser,
    db: DbSession,
) -> RoomResponse:
    """Create a new game room."""
    service = LobbyService(db)

    try:
        room = await service.create_room(
            host_id=current_user.id,
            name=data.name,
            scenario_version_id=data.scenario_version_id,
            max_players=data.max_players,
            character_id=data.character_id,
        )
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return _build_room_response(room)


@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(
    room_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> RoomResponse:
    """Get room details."""
    service = LobbyService(db)

    try:
        room = await service.get_room(room_id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "not_found", "message": str(e)},
        )

    return _build_room_response(room)


@router.post("/{room_id}/join")
async def join_room(
    room_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
):
    """Request to join a room."""
    service = LobbyService(db)

    try:
        await service.join_room(room_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": str(e)},
            )
        if "already" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": "conflict", "message": str(e)},
            )
        if "full" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": "room_full", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return {"success": True, "message": "Join request sent"}


@router.post("/{room_id}/players/{player_id}/approve")
async def approve_player(
    room_id: UUID,
    player_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
):
    """Approve a player's join request (host only)."""
    service = LobbyService(db)

    try:
        await service.approve_player(room_id, player_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": str(e)},
            )
        if "host" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "forbidden", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return {"success": True, "message": "Player approved"}


@router.post("/{room_id}/players/{player_id}/decline")
async def decline_player(
    room_id: UUID,
    player_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
):
    """Decline a player's join request (host only)."""
    service = LobbyService(db)

    try:
        await service.decline_player(room_id, player_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": str(e)},
            )
        if "host" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "forbidden", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return {"success": True, "message": "Player declined"}


@router.post("/{room_id}/ready")
async def toggle_ready(
    room_id: UUID,
    data: ReadyRequest,
    current_user: CurrentUser,
    db: DbSession,
):
    """Toggle ready status."""
    service = LobbyService(db)

    try:
        await service.toggle_ready(
            room_id, current_user.id, data.character_id, data.ready
        )
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg or "not owned" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": "bad_request", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return {"success": True, "message": "Ready status updated"}


@router.post("/{room_id}/start", response_model=GameSessionResponse)
async def start_game(
    room_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> GameSessionResponse:
    """Start the game (host only, all players must be ready)."""
    service = LobbyService(db)

    try:
        game_session = await service.start_game(room_id, current_user.id)
    except ValueError as e:
        error_msg = str(e).lower()
        if "not found" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "not_found", "message": str(e)},
            )
        if "host" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "forbidden", "message": str(e)},
            )
        if "not all" in error_msg or "at least" in error_msg or "not in waiting" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": "bad_request", "message": str(e)},
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "bad_request", "message": str(e)},
        )

    return GameSessionResponse(
        id=game_session.id,
        room_id=game_session.room_id,
        world_state=game_session.world_state,
        started_at=game_session.started_at,
    )


@router.get(
    "/{room_id}/voice-token",
    response_model=VoiceTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Get Agora voice token",
    description="Get an Agora RTC token to join the voice channel for a room",
    tags=["Voice"],
)
async def get_voice_token(
    room_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> VoiceTokenResponse:
    """Get Agora voice token for a room.

    - Room must be in ACTIVE status
    - User must be a player in the room
    - Returns token, channel name, uid, app_id, and expiry

    Error codes:
    - 403: User is not a player in this room
    - 404: Room not found
    - 409: Room is not in ACTIVE status
    - 503: Agora credentials not configured
    """
    settings = get_settings()

    # Check if Agora is configured
    if not settings.agora_app_id or not settings.agora_app_certificate:
        logger.warning("agora_not_configured", room_id=str(room_id))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Voice chat is not configured",
        )

    # Get room with players
    result = await db.execute(
        select(Room)
        .options(selectinload(Room.players))
        .where(Room.id == room_id)
    )
    room = result.scalar_one_or_none()

    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )

    # Check room status
    if room.status != RoomStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Room is not in active status",
        )

    # Check if user is a player in the room
    is_player = any(p.user_id == current_user.id for p in room.players)
    if not is_player:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not a player in this room",
        )

    # Generate token
    response = create_voice_token_response(
        app_id=settings.agora_app_id,
        app_certificate=settings.agora_app_certificate,
        room_id=str(room_id),
        user_id=current_user.id,
        expire_seconds=settings.agora_token_expire_seconds,
    )

    logger.info(
        "voice_token_issued: user_id=%s, room_id=%s, expires_at=%s",
        str(current_user.id),
        str(room_id),
        response.expires_at.isoformat(),
    )

    return response
