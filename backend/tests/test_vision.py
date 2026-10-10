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
    assert resp.status_code == 200
    assert resp.get_json() == {"report_date": None, "media_asset_id": asset_id, "candidates": []}
    # Nothing is written by a scan — saving is the user's call, after review.
    assert auth_client.get("/api/v1/lab-results").get_json() == []


def test_lab_scan_accepts_a_pdf_document(auth_client, app, monkeypatch):
    from app.extensions import db
    from app.media.models import MediaAsset

    me = auth_client.get("/api/v1/auth/me").get_json()
    with app.app_context():
        asset = MediaAsset(user_id=me["id"], kind="document", storage_key="document/r.pdf", content_type="application/pdf")
        db.session.add(asset)
        db.session.commit()
        asset_id = asset.id

    seen = {}

    def fake_read(self, file_bytes, mime_type):
        seen["mime"] = mime_type
        return {
            "report_date": "2026-09-30",
            "results": [{"test_name": "HbA1c", "value": "5.9", "unit": "%", "reference_range": "4.0-5.6"}],
        }

    monkeypatch.setattr("app.medical_profile.routes.download_bytes", lambda key: b"%PDF-1.4 fake")
    monkeypatch.setattr("app.common.llm.mock_provider.MockProvider.read_lab_report", fake_read)

    resp = auth_client.post("/api/v1/lab-results/scan", json={"media_asset_id": asset_id})
    assert resp.status_code == 200
    body = resp.get_json()
    assert seen["mime"] == "application/pdf"
    assert body["report_date"] == "2026-09-30"
    assert body["candidates"][0]["reference_range"] == "4.0-5.6"


def test_reviewed_values_are_saved_in_bulk_with_the_report_date(auth_client, app):
    me = auth_client.get("/api/v1/auth/me").get_json()
    asset_id = _create_media_asset(app, me["id"])

    resp = auth_client.post(
        "/api/v1/lab-results/bulk",
        json={
            "taken_at": "2026-09-30T00:00:00+05:30",
            "media_asset_id": asset_id,
            "results": [
                {"test_name": "Fasting glucose", "value": "104", "unit": "mg/dL", "reference_range": "70-100"},
                {"test_name": "HbA1c", "value": "5.9", "unit": "%"},
            ],
        },
    )
    assert resp.status_code == 201
    saved = auth_client.get("/api/v1/lab-results").get_json()
    assert len(saved) == 2
    assert {r["source"] for r in saved} == {"ocr"}
    assert saved[0]["taken_at"].startswith("2026-09-29T18:30")  # stored as UTC
    assert any(r["reference_range"] == "70-100" for r in saved)


def test_bulk_save_rejects_an_empty_review(auth_client):
    resp = auth_client.post("/api/v1/lab-results/bulk", json={"taken_at": "2026-09-30T00:00:00Z", "results": []})
    assert resp.status_code == 422


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
