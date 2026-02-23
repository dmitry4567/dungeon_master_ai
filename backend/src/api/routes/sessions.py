"""Session REST API routes."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from src.api.dependencies import CurrentUser, DbSession
from src.schemas.session import (
    GameSessionResponse,
    SendMessageRequest,
    SessionMessageResponse,
    WorldStateResponse,
)
from src.services.session_service import SessionService

router = APIRouter(prefix="/sessions", tags=["Sessions"])


@router.get("/{session_id}", response_model=GameSessionResponse)
async def get_session(
    session_id: UUID,
    db: DbSession,
    current_user: CurrentUser,
):
    """Get game session details.

    Returns the session with messages and world state.
    Only accessible by players in the session's room.
    """
    service = SessionService(db)
    try:
        session = await service.get_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    # Check if user is in the room
    players = await service.get_session_players(session_id)
    if not any(p["id"] == str(current_user.id) for p in players):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this session's room",
        )

    # Build response with messages
    messages = []
    for msg in session.messages:
        messages.append(
            SessionMessageResponse(
                id=msg.id,
                author_id=msg.author_id,
                author_name=msg.author.name if msg.author else None,
                role=msg.role.value,
                content=msg.content,
                dice_result=msg.dice_result,
                state_delta=msg.state_delta,
                created_at=msg.created_at,
            )
        )

    return GameSessionResponse(
        id=session.id,
        room_id=session.room_id,
        world_state=session.world_state,
        started_at=session.started_at,
        ended_at=session.ended_at,
        messages=messages,
    )


@router.get("/{session_id}/state", response_model=WorldStateResponse)
async def get_session_state(
    session_id: UUID,
    db: DbSession,
    current_user: CurrentUser,
):
    """Get current world state for a session."""
    service = SessionService(db)
    try:
        session = await service.get_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    # Check if user is in the room
    players = await service.get_session_players(session_id)
    if not any(p["id"] == str(current_user.id) for p in players):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this session's room",
        )

    return WorldStateResponse(**session.world_state)


@router.get("/{session_id}/messages", response_model=list[SessionMessageResponse])
async def get_session_messages(
    session_id: UUID,
    db: DbSession,
    current_user: CurrentUser,
    limit: int = 50,
    offset: int = 0,
):
    """Get messages for a session.

    Returns messages in chronological order with pagination.
    """
    service = SessionService(db)
    try:
        session = await service.get_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    # Check if user is in the room
    players = await service.get_session_players(session_id)
    if not any(p["id"] == str(current_user.id) for p in players):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this session's room",
        )

    # Paginate messages
    messages = session.messages[offset : offset + limit]

    return [
        SessionMessageResponse(
            id=msg.id,
            author_id=msg.author_id,
            author_name=msg.author.name if msg.author else None,
            role=msg.role.value,
            content=msg.content,
            dice_result=msg.dice_result,
            state_delta=msg.state_delta,
            created_at=msg.created_at,
        )
        for msg in messages
    ]


@router.post("/{session_id}/messages", response_model=SessionMessageResponse)
async def send_message(
    session_id: UUID,
    request: SendMessageRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    """Send a player message to the session.

    Note: This is a REST fallback. For real-time gameplay,
    use the WebSocket connection at /ws/session/{room_id}.
    """
    service = SessionService(db)
    try:
        session = await service.get_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    # Check if user is in the room
    players = await service.get_session_players(session_id)
    if not any(p["id"] == str(current_user.id) for p in players):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this session's room",
        )

    # Check if session is still active
    if session.ended_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session has ended",
        )

    message = await service.add_player_message(
        session_id,
        current_user.id,
        request.content,
    )

    return SessionMessageResponse(
        id=message.id,
        author_id=message.author_id,
        author_name=current_user.name,
        role=message.role.value,
        content=message.content,
        dice_result=message.dice_result,
        state_delta=message.state_delta,
        created_at=message.created_at,
    )


@router.post("/{session_id}/end")
async def end_session(
    session_id: UUID,
    db: DbSession,
    current_user: CurrentUser,
):
    """End a game session.

    Only the host can end the session.
    """
    service = SessionService(db)
    try:
        session = await service.get_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    # Check if user is the host
    if session.room.host_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the host can end the session",
        )

    if session.ended_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session has already ended",
        )

    session = await service.end_session(session_id)

    return {"message": "Session ended", "ended_at": session.ended_at.isoformat()}


@router.get("/by-room/{room_id}", response_model=GameSessionResponse)
async def get_session_by_room(
    room_id: UUID,
    db: DbSession,
    current_user: CurrentUser,
):
    """Get game session for a room."""
    service = SessionService(db)
    session = await service.get_session_by_room(room_id)

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No session found for this room",
        )

    # Check if user is in the room
    players = await service.get_session_players(session.id)
    if not any(p["id"] == str(current_user.id) for p in players):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this room",
        )

    messages = [
        SessionMessageResponse(
            id=msg.id,
            author_id=msg.author_id,
            author_name=msg.author.name if msg.author else None,
            role=msg.role.value,
            content=msg.content,
            dice_result=msg.dice_result,
            state_delta=msg.state_delta,
            created_at=msg.created_at,
        )
        for msg in session.messages
    ]

    return GameSessionResponse(
        id=session.id,
        room_id=session.room_id,
        world_state=session.world_state,
        started_at=session.started_at,
        ended_at=session.ended_at,
        messages=messages,
    )
