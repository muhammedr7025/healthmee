def test_register_and_login(client):
    resp = client.post("/api/v1/auth/register", json={"email": "a@b.com", "password": "password123"})
    assert resp.status_code == 201
    assert resp.get_json()["access_token"]

    resp = client.post("/api/v1/auth/register", json={"email": "a@b.com", "password": "password123"})
    assert resp.status_code == 409

    resp = client.post("/api/v1/auth/login", json={"email": "a@b.com", "password": "wrong"})
    assert resp.status_code == 401

    resp = client.post("/api/v1/auth/login", json={"email": "a@b.com", "password": "password123"})
    assert resp.status_code == 200


def test_me_requires_auth(auth_client):
    resp = auth_client.get("/api/v1/auth/me")
    assert resp.status_code == 200
    assert resp.get_json()["email"] == "test@example.com"
