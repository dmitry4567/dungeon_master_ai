from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from src.api.routes import auth, characters, rooms, scenarios, sessions, users, websocket
from src.core.config import get_settings
from src.core.database import close_db, init_db
from src.core.logging import setup_logging
from src.core.redis import close_redis, get_redis
from src.schemas.common import ErrorResponse

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    setup_logging()
    await init_db()
    await get_redis()
    yield
    await close_redis()
    await close_db()


app = FastAPI(
    title="AI Dungeon Master API",
    description="Backend API for AI-powered D&D 5e game master",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(characters.router, prefix="/api/v1")
app.include_router(scenarios.router, prefix="/api/v1")
app.include_router(rooms.router, prefix="/api/v1")
app.include_router(sessions.router, prefix="/api/v1")
app.include_router(websocket.router, prefix="/api/v1")


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint."""
    return {"status": "ok"}


@app.get("/health/ready", tags=["Health"])
async def readiness_check():
    """Readiness check with database and redis connectivity."""
    from src.core.database import engine
    from src.core.redis import get_redis

    checks = {"database": "unknown", "redis": "unknown"}

    try:
        async with engine.connect() as conn:
            await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
        checks["database"] = "connected"
    except Exception:
        checks["database"] = "disconnected"

    try:
        redis = await get_redis()
        await redis.ping()
        checks["redis"] = "connected"
    except Exception:
        checks["redis"] = "disconnected"

    status = "ok" if all(v == "connected" for v in checks.values()) else "degraded"

    return {"status": status, **checks}


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler."""
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="internal_server_error",
            message="An unexpected error occurred",
            details=str(exc) if settings.app_debug else None,
        ).model_dump(),
    )
