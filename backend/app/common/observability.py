"""Request logging, request ids, error tracking and a health check that
actually checks something.

Before this there were two log lines in the whole app and a /health that
returned "ok" with the database down.
"""

import json
import logging
import sys
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, g, has_request_context, request
from sqlalchemy import text

from app.extensions import db


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if has_request_context():
            payload["request_id"] = getattr(g, "request_id", None)
        for key in ("method", "path", "status", "duration_ms", "user_id", "event"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def init_observability(app: Flask) -> None:
    _configure_logging(app)
    _register_request_hooks(app)
    _register_health(app)
    _init_sentry(app)


def _configure_logging(app: Flask) -> None:
    if app.config.get("TESTING"):
        return  # pytest's own capture is more useful than JSON lines in tests
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(app.config.get("LOG_LEVEL", "INFO"))
    app.logger.handlers = []  # inherit the root handler, don't double-log
    app.logger.propagate = True


def _register_request_hooks(app: Flask) -> None:
    access = logging.getLogger("healthmee.access")

    @app.before_request
    def _start():
        g.request_id = (request.headers.get("X-Request-ID") or uuid.uuid4().hex[:16])[:64]
        g.request_started = time.perf_counter()

    @app.after_request
    def _finish(response):
        response.headers["X-Request-ID"] = getattr(g, "request_id", "")
        if request.path != "/health" and not app.config.get("TESTING"):
            duration_ms = round((time.perf_counter() - getattr(g, "request_started", time.perf_counter())) * 1000)
            access.info(
                "%s %s %s",
                request.method,
                request.path,
                response.status_code,
                extra={
                    "event": "request",
                    "method": request.method,
                    "path": request.path,
                    "status": response.status_code,
                    "duration_ms": duration_ms,
                    "user_id": _current_user_id(),
                },
            )
        return response


def _current_user_id() -> str | None:
    """Best effort, never raises — logging must not depend on a valid token."""
    try:
        from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

        verify_jwt_in_request(optional=True)
        return get_jwt_identity()
    except Exception:
        return None


def _register_health(app: Flask) -> None:
    @app.get("/health")
    def health_check():
        checks = {}
        try:
            db.session.execute(text("SELECT 1"))
            checks["db"] = "ok"
        except Exception:
            checks["db"] = "fail"
        try:
            checks["migration"] = db.session.execute(text("SELECT version_num FROM alembic_version")).scalar()
        except Exception:
            checks["migration"] = None
        try:
            import redis

            redis.from_url(app.config["CELERY_BROKER_URL"], socket_connect_timeout=1, socket_timeout=1).ping()
            checks["redis"] = "ok"
        except Exception:
            checks["redis"] = "fail"
        checks["llm_provider"] = app.config.get("LLM_PROVIDER")
        healthy = checks["db"] == "ok" and checks["redis"] == "ok"
        return {"status": "ok" if healthy else "degraded", **checks}, (200 if healthy else 503)


def _init_sentry(app: Flask) -> None:
    dsn = app.config.get("SENTRY_DSN")
    if not dsn:
        return
    try:
        import sentry_sdk
        from sentry_sdk.integrations.flask import FlaskIntegration

        sentry_sdk.init(
            dsn=dsn,
            integrations=[FlaskIntegration()],
            traces_sample_rate=float(app.config.get("SENTRY_TRACES_SAMPLE_RATE", 0.1)),
            send_default_pii=False,  # health data: never ship request bodies or user emails
            environment=app.config.get("SENTRY_ENVIRONMENT", "production"),
        )
    except Exception:
        app.logger.exception("Sentry init failed; continuing without it")
