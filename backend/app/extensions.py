from celery import Celery
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
cors = CORS()
celery = Celery(__name__)


def user_or_ip() -> str:
    """Rate-limit key: the signed-in user when there is one, else the IP —
    so one person can't exhaust a shared office/NAT address's allowance."""
    try:
        from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

        verify_jwt_in_request(optional=True)
        identity = get_jwt_identity()
        if identity:
            return f"user:{identity}"
    except Exception:
        pass
    return get_remote_address()


# No default limit: each sensitive route declares its own. Storage comes from
# config (Redis in production, memory in tests).
limiter = Limiter(key_func=get_remote_address, default_limits=[], headers_enabled=True)


def init_celery(app):
    celery.conf.update(
        broker_url=app.config["CELERY_BROKER_URL"],
        result_backend=app.config["CELERY_RESULT_BACKEND"],
        task_ignore_result=True,  # nothing reads results; don't fill Redis with them
        task_acks_late=True,
        task_time_limit=120,
        broker_connection_retry_on_startup=True,
        beat_schedule={
            "check-push-reminders": {
                "task": "push.check_reminders",
                # Every 5 minutes so a medicine due at 08:00 is nudged by 08:05;
                # dedupe keys keep every reminder kind idempotent.
                "schedule": 5 * 60,
            },
            "reconcile-daily-aggregates": {
                "task": "analytics.reconcile_recent_days",
                "schedule": 6 * 60 * 60,  # a safety net under the inline recompute
            },
        },
    )

    class ContextTask(celery.Task):
        def __call__(self, *args, **kwargs):
            with app.app_context():
                return self.run(*args, **kwargs)

    celery.Task = ContextTask
    return celery
