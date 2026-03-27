from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://localintel:localintel_dev@localhost:5432/localintel"
    database_url_sync: str = "postgresql://localintel:localintel_dev@localhost:5432/localintel"
    app_title: str = "LocalIntel — SSA Inequality Mapping Engine"
    debug: bool = True

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    return Settings()
