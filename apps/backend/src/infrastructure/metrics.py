from time import perf_counter

from fastapi import FastAPI, Request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from starlette.responses import Response

REQUEST_COUNT = Counter("http_requests_total", "Total request count", ["method", "path", "status"])
REQUEST_LATENCY = Histogram("http_request_latency_seconds", "HTTP request latency", ["method", "path"])
ACTIVE_SESSIONS = Gauge("active_sessions_total", "Active radar sessions")
ACTIVE_CONNECTIONS = Gauge("active_connections_total", "Active websocket connections")
WS_BROADCAST_LATENCY = Histogram("ws_broadcast_latency_seconds", "WebSocket broadcast latency")
LOCATION_UPDATES = Counter("location_updates_per_second", "Location updates processed")


def increment_active_sessions() -> None:
    ACTIVE_SESSIONS.inc()


def decrement_active_sessions() -> None:
    ACTIVE_SESSIONS.dec()


def increment_active_connections() -> None:
    ACTIVE_CONNECTIONS.inc()


def decrement_active_connections() -> None:
    ACTIVE_CONNECTIONS.dec()


def observe_ws_broadcast_latency(seconds: float) -> None:
    WS_BROADCAST_LATENCY.observe(seconds)


def increment_location_updates() -> None:
    LOCATION_UPDATES.inc()


def bind_metrics(app: FastAPI) -> None:
    @app.middleware("http")
    async def metrics_middleware(request: Request, call_next):
        start = perf_counter()
        response = await call_next(request)
        elapsed = perf_counter() - start
        path = request.url.path
        REQUEST_COUNT.labels(request.method, path, response.status_code).inc()
        REQUEST_LATENCY.labels(request.method, path).observe(elapsed)
        return response

    @app.get("/metrics", include_in_schema=False)
    async def metrics() -> Response:
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
