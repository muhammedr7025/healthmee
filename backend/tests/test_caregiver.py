def _register_and_login(client, email):
    client.post("/api/v1/auth/register", json={"email": email, "password": "password123"})
    resp = client.post("/api/v1/auth/login", json={"email": email, "password": "password123"})
    return resp.get_json()["access_token"]


def test_invite_accept_and_view_summary(client):
    owner_token = _register_and_login(client, "owner@example.com")
    caregiver_token = _register_and_login(client, "caregiver@example.com")

    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {owner_token}"
    resp = client.post(
        "/api/v1/caregiver/links",
        json={"email": "caregiver@example.com", "can_view_logs": True, "can_view_trends_reports": True},
    )
    assert resp.status_code == 201
    link_id = resp.get_json()["id"]
    assert resp.get_json()["status"] == "pending"

    # log something as the owner so the caregiver has something to see
    client.post("/api/v1/chat/messages", json={"text": "slept 7 hours"})

    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {caregiver_token}"
    resp = client.get("/api/v1/caregiver/invitations")
    assert resp.status_code == 200
    assert len(resp.get_json()) == 1

    resp = client.post(f"/api/v1/caregiver/invitations/{link_id}/accept")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "active"

    resp = client.get("/api/v1/caregiver/access")
    assert resp.status_code == 200
    assert resp.get_json()[0]["owner_email"] == "owner@example.com"

    owner_id = resp.get_json()[0]["owner_user_id"]
    resp = client.get(f"/api/v1/caregiver/access/{owner_id}/summary")
    assert resp.status_code == 200
    assert resp.get_json()["owner_email"] == "owner@example.com"


def test_cannot_invite_self(auth_client):
    me = auth_client.get("/api/v1/auth/me").get_json()
    resp = auth_client.post("/api/v1/caregiver/links", json={"email": me["email"]})
    assert resp.status_code == 400


def test_revoke_link(client):
    owner_token = _register_and_login(client, "owner2@example.com")
    _register_and_login(client, "caregiver2@example.com")

    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {owner_token}"
    resp = client.post("/api/v1/caregiver/links", json={"email": "caregiver2@example.com"})
    link_id = resp.get_json()["id"]

    resp = client.delete(f"/api/v1/caregiver/links/{link_id}")
    assert resp.status_code == 204

    resp = client.get("/api/v1/caregiver/links")
    assert resp.get_json()[0]["status"] == "revoked"
