from flask import Flask
from flask_smorest import Api

from config import Config
from app.extensions import cors, db, init_celery, jwt, migrate


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    cors.init_app(app)
    init_celery(app)

    _import_models()

    from app.logging.types import register_builtin_types

    register_builtin_types()

    api = Api(app)
    _register_blueprints(api)

    @app.get("/health")
    def health_check():
        return {"status": "ok"}

    return app


def _import_models():
    from app.accounts import models as _accounts_models  # noqa: F401
    from app.analytics import models as _analytics_models  # noqa: F401
    from app.billing import models as _billing_models  # noqa: F401
    from app.caregiver import models as _caregiver_models  # noqa: F401
    from app.goals import models as _goals_models  # noqa: F401
    from app.logging import models as _logging_models  # noqa: F401
    from app.media import models as _media_models  # noqa: F401
    from app.medical_profile import models as _medical_profile_models  # noqa: F401
    from app.notifications import models as _notifications_models  # noqa: F401


def _register_blueprints(api: Api):
    from app.accounts.routes import blp as accounts_blp
    from app.analytics.routes import blp as analytics_blp
    from app.billing.routes import blp as billing_blp
    from app.caregiver.routes import blp as caregiver_blp
    from app.goals.routes import blp as goals_blp
    from app.logging.routes import blp as logging_blp
    from app.media.routes import blp as media_blp
    from app.medical_profile.routes import blp as medical_profile_blp
    from app.notifications.routes import blp as notifications_blp
    from app.reports.routes import blp as reports_blp

    for blp in (
        accounts_blp,
        medical_profile_blp,
        logging_blp,
        analytics_blp,
        goals_blp,
        media_blp,
        notifications_blp,
        reports_blp,
        caregiver_blp,
        billing_blp,
    ):
        api.register_blueprint(blp)
