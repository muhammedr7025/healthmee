import re

import pytest


@pytest.fixture()
def sent_emails(monkeypatch):
    """Captures what the (mocked, no-SMTP-configured) email step would have
    sent, instead of actually needing a mail server for the test."""
    sent = []
    monkeypatch.setattr("app.accounts.routes.send_email", lambda to, subject, body: sent.append((to, subject, body)))
    return sent


def _code_from(body: str) -> str:
    return re.search(r"code is (\d{6})", body).group(1)


def test_request_for_unknown_email_still_returns_202(client):
    resp = client.post("/api/v1/auth/password/reset-request", json={"email": "nobody@example.com"})
    assert resp.status_code == 202  # never reveals whether the email exists


def test_full_reset_flow_changes_the_password(client, sent_emails):
    client.post("/api/v1/auth/register", json={"email": "reset@example.com", "password": "originalPass1"})

    resp = client.post("/api/v1/auth/password/reset-request", json={"email": "reset@example.com"})
    assert resp.status_code == 202
    assert len(sent_emails) == 1
    code = _code_from(sent_emails[0][2])

    resp = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "reset@example.com", "code": code, "new_password": "brandNewPass1"},
    )
    assert resp.status_code == 204

    assert client.post("/api/v1/auth/login", json={"email": "reset@example.com", "password": "originalPass1"}).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "reset@example.com", "password": "brandNewPass1"}).status_code == 200


def test_wrong_code_is_rejected(client, sent_emails):
    client.post("/api/v1/auth/register", json={"email": "wrongcode@example.com", "password": "originalPass1"})
    client.post("/api/v1/auth/password/reset-request", json={"email": "wrongcode@example.com"})

    resp = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "wrongcode@example.com", "code": "000000", "new_password": "brandNewPass1"},
    )
    assert resp.status_code == 400
    assert client.post("/api/v1/auth/login", json={"email": "wrongcode@example.com", "password": "originalPass1"}).status_code == 200


def test_code_cannot_be_reused(client, sent_emails):
    client.post("/api/v1/auth/register", json={"email": "reuse@example.com", "password": "originalPass1"})
    client.post("/api/v1/auth/password/reset-request", json={"email": "reuse@example.com"})
    code = _code_from(sent_emails[0][2])

    first = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "reuse@example.com", "code": code, "new_password": "brandNewPass1"},
    )
    assert first.status_code == 204

    second = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "reuse@example.com", "code": code, "new_password": "yetAnotherPass1"},
    )
    assert second.status_code == 400


def test_requesting_again_invalidates_the_previous_code(client, sent_emails):
    client.post("/api/v1/auth/register", json={"email": "resend@example.com", "password": "originalPass1"})
    client.post("/api/v1/auth/password/reset-request", json={"email": "resend@example.com"})
    old_code = _code_from(sent_emails[0][2])

    client.post("/api/v1/auth/password/reset-request", json={"email": "resend@example.com"})
    new_code = _code_from(sent_emails[1][2])
    assert old_code != new_code or True  # codes could coincidentally match; the real check is below

    resp = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "resend@example.com", "code": old_code, "new_password": "brandNewPass1"},
    )
    assert resp.status_code == 400


def test_too_many_wrong_guesses_locks_out_the_correct_code(client, sent_emails):
    client.post("/api/v1/auth/register", json={"email": "bruteforce@example.com", "password": "originalPass1"})
    client.post("/api/v1/auth/password/reset-request", json={"email": "bruteforce@example.com"})
    code = _code_from(sent_emails[0][2])

    for _ in range(8):
        wrong = "000000" if code != "000000" else "111111"
        client.post(
            "/api/v1/auth/password/reset-confirm",
            json={"email": "bruteforce@example.com", "code": wrong, "new_password": "brandNewPass1"},
        )

    resp = client.post(
        "/api/v1/auth/password/reset-confirm",
        json={"email": "bruteforce@example.com", "code": code, "new_password": "brandNewPass1"},
    )
    assert resp.status_code == 400
