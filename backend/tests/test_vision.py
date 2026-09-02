def _create_media_asset(app, user_id):
    from app.extensions import db
    from app.media.models import MediaAsset

    with app.app_context():
        asset = MediaAsset(user_id=user_id, kind="photo", storage_key="photo/test.jpg", content_type="image/jpeg")
        db.session.add(asset)
        db.session.commit()
        return asset.id


def test_chat_photo_with_no_provider_degrades_gracefully(auth_client, app):
    """No real S3 running in tests, so download_bytes() will fail — the
    pipeline should degrade to text-only extraction rather than 500."""
    me = auth_client.get("/api/v1/auth/me").get_json()
    asset_id = _create_media_asset(app, me["id"])

    resp = auth_client.post(
        "/api/v1/chat/messages", json={"text": "I slept 7 hours last night", "media_asset_id": asset_id}
    )
    assert resp.status_code == 201
    assert resp.get_json()["entries"][0]["type"] == "sleep"


def test_chat_photo_mock_provider_is_honest_about_not_seeing_it(auth_client, app, monkeypatch):
    me = auth_client.get("/api/v1/auth/me").get_json()
    asset_id = _create_media_asset(app, me["id"])
    monkeypatch.setattr("app.logging.extraction.pipeline.download_bytes", lambda key: b"fake-jpeg-bytes")

    resp = auth_client.post("/api/v1/chat/messages", json={"text": "", "media_asset_id": asset_id})
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["entries"] == []
    assert "photo" in body["reply"].lower()
    assert "AI connected" in body["reply"]


def test_lab_scan_mock_provider_returns_nothing(auth_client, app, monkeypatch):
    me = auth_client.get("/api/v1/auth/me").get_json()
    asset_id = _create_media_asset(app, me["id"])
    monkeypatch.setattr("app.medical_profile.routes.download_bytes", lambda key: b"fake-jpeg-bytes")

    resp = auth_client.post("/api/v1/lab-results/scan", json={"media_asset_id": asset_id})
    assert resp.status_code == 201
    assert resp.get_json() == []


def test_lab_scan_rejects_video_asset(auth_client, app):
    from app.extensions import db
    from app.media.models import MediaAsset

    me = auth_client.get("/api/v1/auth/me").get_json()
    with app.app_context():
        asset = MediaAsset(user_id=me["id"], kind="video", storage_key="video/test.mp4", content_type="video/mp4")
        db.session.add(asset)
        db.session.commit()
        asset_id = asset.id

    resp = auth_client.post("/api/v1/lab-results/scan", json={"media_asset_id": asset_id})
    assert resp.status_code == 400
