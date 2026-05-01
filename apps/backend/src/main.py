import json
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, WebSocket
from fastapi.responses import JSONResponse
from fastapi.routing import APIRouter
from fastapi.middleware.cors import CORSMiddleware

from src.api.v1.routes.auth import router as auth_router
from src.api.v1.routes.health import router as health_router
from src.api.v1.routes.sessions import router as sessions_router
from src.core.config import settings
from src.core.exceptions import DomainError
from src.core.logging import configure_logging
from src.infrastructure.middleware import (
    request_id_middleware,
)
from src.infrastructure.redis_client import close_redis, init_redis, register_expiry_callback
from src.repositories.session_repository import SessionRepository
from src.services.websocket_service import WebSocketService

configure_logging()
# Observability disabled for MVP
session_repository = SessionRepository()
websocket_service = WebSocketService()


@asynccontextmanager
async def lifespan(_: FastAPI):
    register_expiry_callback(session_repository.on_expired_key)
    await init_redis()
    yield
    await close_redis()


app = FastAPI(title="Ephemeral Radar Backend", version="0.1.0", lifespan=lifespan)
app.middleware("http")(request_id_middleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=json.loads(settings.cors_allowed_origins),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.message,
            "code": exc.code,
            "request_id": getattr(request.state, "request_id", "unknown"),
        },
    )


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth_router)
api_router.include_router(health_router)
api_router.include_router(sessions_router)
app.include_router(api_router)
# Metrics disabled for MVP


@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    token = websocket.query_params.get("token", "")
    await websocket_service.handle_connection(websocket, session_id=session_id, token=token)


