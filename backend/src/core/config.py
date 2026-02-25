from __future__ import annotations

from functools import lru_cache
from typing import Any

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_env: str = Field(default="development", alias="APP_ENV")
    app_debug: bool = Field(default=False, alias="APP_DEBUG")
    app_host: str = Field(default="0.0.0.0", alias="APP_HOST")
    app_port: int = Field(default=8000, alias="APP_PORT")

    # Database
    database_url: str = Field(
        default="postgresql+asyncpg://aidm:aidm@localhost:5432/aidm",
        alias="DATABASE_URL",
    )

    # Redis
    redis_url: str = Field(default="redis://localhost:6379/0", alias="REDIS_URL")

    # Anthropic Claude API
    ANTHROPIC_API_KEY: str = Field(default="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", alias="ANTHROPIC_API_KEY")
    
    # Model selection for different request types
    model_dm_response: str = Field(
        default="claude-haiku-4-5-20251001",
        alias="MODEL_DM_RESPONSE",
        description="Model for DM responses during gameplay",
    )
    model_scenario_generation: str = Field(
        default="claude-haiku-4-5-20251001",
        alias="MODEL_SCENARIO_GENERATION",
        description="Model for generating new scenarios",
    )
    model_scenario_refinement: str = Field(
        default="claude-haiku-4-5-20251001",
        alias="MODEL_SCENARIO_REFINEMENT",
        description="Model for refining existing scenarios",
    )
    model_state_extraction: str = Field(
        default="claude-haiku-4-5-20251001",
        alias="MODEL_STATE_EXTRACTION",
        description="Model for extracting game state from conversations",
    )

    # JWT Authentication
    jwt_secret_key: str = Field(default="change-me-in-production", alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    jwt_access_token_expire_minutes: int = Field(
        default=10080, alias="JWT_ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    jwt_refresh_token_expire_days: int = Field(default=30, alias="JWT_REFRESH_TOKEN_EXPIRE_DAYS")

    # Apple Sign In
    apple_client_id: str = Field(default="", alias="APPLE_CLIENT_ID")

    # S3/R2 Storage
    s3_endpoint: str = Field(default="", alias="S3_ENDPOINT")
    s3_access_key: str = Field(default="", alias="S3_ACCESS_KEY")
    s3_secret_key: str = Field(default="", alias="S3_SECRET_KEY")
    s3_bucket: str = Field(default="aidm-audio", alias="S3_BUCKET")
    s3_region: str = Field(default="auto", alias="S3_REGION")

    # CORS
    cors_origins: list[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080"],
        alias="CORS_ORIGINS",
    )

    # Rate Limiting
    rate_limit_requests: int = Field(default=60, alias="RATE_LIMIT_REQUESTS")
    rate_limit_period: int = Field(default=60, alias="RATE_LIMIT_PERIOD")

    # Logging
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    log_format: str = Field(default="console", alias="LOG_FORMAT")  # console, json, or dungeon

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: Any) -> list[str]:
        if isinstance(v, str):
            import json

            try:
                return json.loads(v)
            except json.JSONDecodeError:
                return [origin.strip() for origin in v.split(",")]
        return v

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
