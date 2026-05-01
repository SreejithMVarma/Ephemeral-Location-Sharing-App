from pydantic import ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    api_base_url: str
    fcm_sender_id: str
    deep_link_scheme: str
    region_ws_urls: str
    cors_allowed_origins: str
    redis_url: str
    redis_max_connections: int = 100
    redis_enable_keyspace_listener: bool = True
    websocket_max_connections_per_session: int = 50
    websocket_message_max_bytes: int = 2048
    app_env: str = "development"
    sentry_dsn: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_prefix="", extra="ignore")


def load_settings() -> Settings:
    try:
        return Settings()
    except ValidationError as exc:
        missing_fields = [
            ".".join(str(part) for part in err["loc"]) for err in exc.errors()
        ]
        raise RuntimeError(
            f"Missing or invalid required environment keys: {', '.join(missing_fields)}"
        ) from exc


settings = load_settings()

