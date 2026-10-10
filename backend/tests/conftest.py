from datetime import datetime

import pytest

from app import create_app
from app.extensions import db
from config import TestConfig

# What the real app sends: the device's UTC offset in minutes. Using the test
# machine's own offset means `date.today()` in a test and the server's idea
# of "today" agree — which they otherwise don't for ~5.5 hours a day in IST.
LOCAL_TZ_OFFSET_MINUTES = int(datetime.now().astimezone().utcoffset().total_seconds() // 60)


@pytest.fixture()
def app():
    application = create_app(TestConfig)
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def auth_client(client):
    client.post("/api/v1/auth/register", json={"email": "test@example.com", "password": "password123"})
    resp = client.post("/api/v1/auth/login", json={"email": "test@example.com", "password": "password123"})
    token = resp.get_json()["access_token"]
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {token}"
    client.environ_base["HTTP_X_TIMEZONE_OFFSET"] = str(LOCAL_TZ_OFFSET_MINUTES)
    return client
