from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        case_sensitive=False,
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
        validate_by_name=True,
    )

    app_secret: SecretStr = Field(validation_alias="APP_SECRET")
    database_url: str = Field(validation_alias="DATABASE_URL")
    redis_url: str | None = Field(default=None, validation_alias="REDIS_URL")

    @field_validator("app_secret")
    @classmethod
    def validate_app_secret(cls, value: SecretStr) -> SecretStr:
        if not value.get_secret_value().strip():
            raise ValueError("APP_SECRET must not be empty")
        return value

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        url = value.strip()
        if not url:
            raise ValueError("DATABASE_URL must not be empty")
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


def load_settings() -> Settings:
    # Pydantic resolves the required fields from environment variables or the configured .env files.
    return Settings()  # type: ignore[call-arg]
