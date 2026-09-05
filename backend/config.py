import os


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-change-me")

    SQLALCHEMY_DATABASE_URI = os.environ.get(
        "DATABASE_URL", "postgresql://health:health@localhost:5432/health"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-jwt-secret-change-me")
    JWT_ACCESS_TOKEN_EXPIRES = int(os.environ.get("JWT_ACCESS_TOKEN_EXPIRES_SECONDS", 60 * 60 * 24))

    CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")
    CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "redis://localhost:6379/0")

    # Object storage (S3-compatible / MinIO)
    S3_ENDPOINT_URL = os.environ.get("S3_ENDPOINT_URL", "http://localhost:9000")
    # Host the *client* (Flutter app) can reach, for presigned URLs handed
    # back to it — inside Docker Compose, S3_ENDPOINT_URL is the internal
    # `http://minio:9000`, which a mobile simulator/device can't resolve.
    # Falls back to S3_ENDPOINT_URL when unset (e.g. running the backend
    # outside Docker, where there's only one reachable host anyway).
    S3_PUBLIC_ENDPOINT_URL = os.environ.get("S3_PUBLIC_ENDPOINT_URL")
    S3_ACCESS_KEY = os.environ.get("S3_ACCESS_KEY", "minioadmin")
    S3_SECRET_KEY = os.environ.get("S3_SECRET_KEY", "minioadmin")
    S3_BUCKET = os.environ.get("S3_BUCKET", "health-media")
    S3_REGION = os.environ.get("S3_REGION", "us-east-1")

    # LLM provider: "anthropic" | "openai" | "gemini" | "mock"
    LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "mock")
    ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
    ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-5")
    OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
    OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")
    GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")
    GOOGLE_MODEL = os.environ.get("GOOGLE_MODEL", "gemini-3.5-flash-lite")

    # Billing / subscriptions (Stripe). With no STRIPE_SECRET_KEY set, billing
    # runs in "mock" mode: checkout instantly marks the account premium and no
    # network calls are made — same fallback pattern as LLM_PROVIDER=mock.
    STRIPE_SECRET_KEY = os.environ.get("STRIPE_SECRET_KEY")
    STRIPE_PUBLISHABLE_KEY = os.environ.get("STRIPE_PUBLISHABLE_KEY")
    STRIPE_PRICE_ID = os.environ.get("STRIPE_PRICE_ID")
    STRIPE_WEBHOOK_SECRET = os.environ.get("STRIPE_WEBHOOK_SECRET")
    BILLING_SUCCESS_URL = os.environ.get("BILLING_SUCCESS_URL", "vitachat://billing/success")
    BILLING_CANCEL_URL = os.environ.get("BILLING_CANCEL_URL", "vitachat://billing/cancel")
    FREE_TIER_LOGBOOK_DAYS = int(os.environ.get("FREE_TIER_LOGBOOK_DAYS", 30))

    # Chat history: how long the thread can go quiet before reopening the
    # app greets the user with a "we missed you" nudge instead of just
    # picking back up in silence.
    CHAT_IDLE_GREETING_HOURS = int(os.environ.get("CHAT_IDLE_GREETING_HOURS", 6))

    # Push notifications (Firebase Cloud Messaging). Leave unset to run in
    # "mock" mode: the reminder scheduler still runs on its real triggers,
    # but delivery is just a logged PushLog row instead of a real device
    # push — same fallback pattern as LLM_PROVIDER=mock. Set to a path to a
    # Firebase service-account JSON file to go live.
    FCM_CREDENTIALS_JSON = os.environ.get("FCM_CREDENTIALS_JSON")

    API_TITLE = "Health API"
    API_VERSION = "v1"
    OPENAPI_VERSION = "3.0.3"
    OPENAPI_URL_PREFIX = "/api/docs"
    OPENAPI_SWAGGER_UI_PATH = "/swagger"
    OPENAPI_SWAGGER_UI_URL = "https://cdn.jsdelivr.net/npm/swagger-ui-dist/"


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    LLM_PROVIDER = "mock"
