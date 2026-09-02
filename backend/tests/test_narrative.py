def test_narrative_with_no_data(auth_client):
    resp = auth_client.get("/api/v1/trends/narrative?period=week")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["period"] == "week"
    assert body["stats"]["days_logged"] == 0
    assert "Nothing logged" in body["summary"]
    assert body["wins"] == []


def test_narrative_reflects_real_aggregate_data(auth_client, app):
    from datetime import date

    from app.analytics.models import DailyAggregate
    from app.extensions import db

    me = auth_client.get("/api/v1/auth/me").get_json()
    with app.app_context():
        db.session.add(
            DailyAggregate(
                user_id=me["id"],
                date=date.today(),
                total_calories=1800,
                activity_minutes=40,
                sleep_hours=7.5,
                mood_score=4.0,
                water_ml=2000,
                log_count=3,
            )
        )
        db.session.commit()

    resp = auth_client.get("/api/v1/trends/narrative?period=week")
    body = resp.get_json()
    assert body["stats"]["days_logged"] == 1
    assert body["stats"]["avg_sleep"] == 7.5
    assert "1 of the last 7 days" in body["summary"]
    assert "7.5" in body["summary"]
    assert any("sleep" in w.lower() for w in body["wins"])
