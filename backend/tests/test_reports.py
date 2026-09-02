from datetime import date


def test_pdf_generator_produces_real_bytes_from_real_data():
    from app.reports.pdf_generator import build_report_pdf

    pdf_bytes, page_count = build_report_pdf(
        user_name="Ada Lovelace",
        user_email="ada@example.com",
        start=date(2026, 8, 1),
        end=date(2026, 8, 30),
        conditions=["Hypertension"],
        allergies=[{"name": "Peanut", "severity": "severe", "notes": None}],
        medications=["Lisinopril 10mg"],
        baseline_vitals={"weight_kg": 70, "bp_systolic": 128},
        lab_results=[
            {"test_name": "HbA1c", "value": "5.4", "unit": "%", "source": "manual", "taken_at": "2026-08-10T00:00:00"}
        ],
        log_entries=[{"timestamp": "2026-08-10T08:00:00", "type": "sleep", "summary": "Slept 7h"}],
        daily_aggregates=[
            {"date": "2026-08-10", "sleep_hours": 7.0, "mood_score": 4.0, "activity_minutes": 30, "log_count": 1}
        ],
    )

    assert pdf_bytes.startswith(b"%PDF")
    assert page_count >= 1


def test_generate_report_route(auth_client, monkeypatch):
    uploaded = {}

    def fake_upload_bytes(key, data, content_type):
        uploaded["key"] = key
        uploaded["data"] = data

    def fake_presign_download(key, expires_in=900):
        return f"https://fake-s3/{key}?signed=1"

    monkeypatch.setattr("app.reports.routes.upload_bytes", fake_upload_bytes)
    monkeypatch.setattr("app.reports.routes.presign_download", fake_presign_download)

    auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})

    resp = auth_client.post("/api/v1/reports/generate", json={})
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["download_url"].startswith("https://fake-s3/")
    assert body["page_count"] >= 1
    assert uploaded["data"].startswith(b"%PDF")

    resp = auth_client.get("/api/v1/reports")
    assert len(resp.get_json()) == 1

    report_id = body["id"]
    resp = auth_client.delete(f"/api/v1/reports/{report_id}")
    assert resp.status_code == 204
    resp = auth_client.get("/api/v1/reports")
    assert resp.get_json() == []
