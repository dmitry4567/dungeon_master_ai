"""Room API routes."""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status

from src.api.dependencies import CurrentUser, DbSession
from src.models.room import RoomStatus
from src.schemas.room import (
    CreateRoomRequest,
    GameSessionResponse,
    ReadyRequest,
    RoomPlayerResponse,
    RoomResponse,
    RoomSummaryResponse,
)
from src.services.lobby_service import LobbyService

router = APIRouter(prefix="/rooms", tags=["rooms"])


def _build_room_response(room) -> RoomResponse:
    """Build a RoomResponse from a Room model with loaded relationships."""
    players = []
    for p in room.players:
        player_resp = RoomPlayerResponse(
            id=p.id,
            user_id=p.user_id,
            name=p.user.name if p.user else "Unknown",
            character=None,
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


def _build_room_summary(room) -> RoomSummaryResponse:
    """Build a RoomSummaryResponse from a Room model."""
    active_players = [
        p for p in room.players
        if (p.status.value if hasattr(p.status, "value") else p.status) != "declined"
    ]
    scenario_title = "Unknown"
    if room.scenario_version and room.scenario_version.scenario:
        scenario_title = room.scenario_version.scenario.title

    return RoomSummaryResponse(
        id=room.id,
        name=room.name,
        scenario_title=scenario_title,
        host_name=room.host.name if room.host else "Unknown",
        player_count=len(active_players),
        max_players=room.max_players,
        status=room.status.value if hasattr(room.status, "value") else room.status,
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
    return [_build_room_summary(r) for r in rooms]


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


@router.post("/{room_id}/start")
async def start_game(
    room_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
):
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

    return game_session
