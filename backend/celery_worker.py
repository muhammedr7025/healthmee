from app import create_app
from app.extensions import celery

flask_app = create_app()
flask_app.app_context().push()

# Task modules are only imported lazily from request handlers (to avoid
# import-time circular deps), so nothing registers them on this process's
# Celery app unless we do it here — without this, the worker receives
# .delay()'d (or beat-scheduled) tasks it doesn't recognize and drops them
# (KeyError on the task name).
from app.analytics import tasks as _analytics_tasks  # noqa: E402,F401
from app.push import scheduler as _push_scheduler  # noqa: E402,F401
