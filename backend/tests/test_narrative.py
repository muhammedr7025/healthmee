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
    assert body["momentum"]["label"] == "starting"  # nothing the week before to compare with
    assert body["previous"]["days_logged"] == 0


def test_narrative_compares_with_the_previous_period_and_flags_readings(auth_client, app):
    from datetime import date, timedelta

    from app.analytics.models import DailyAggregate
    from app.extensions import db

    me = auth_client.get("/api/v1/auth/me").get_json()
    today = date.today()
    with app.app_context():
        # Last week: logged 2 days, little sleep. This week: 5 days, better sleep, high BP, sugar creeping.
        for offset in (8, 10):
            db.session.add(DailyAggregate(user_id=me["id"], date=today - timedelta(days=offset), sleep_hours=5.5, log_count=1))
        for offset in range(5):
            db.session.add(
                DailyAggregate(
                    user_id=me["id"],
                    date=today - timedelta(days=offset),
                    sleep_hours=7.2,
                    water_ml=1200,
                    log_count=2,
                    systolic=146,
                    diastolic=92,
                    glucose_mg_dl=108,
                    weight_kg=80 - offset * 0.6,  # 2.4 kg over the window
                )
            )
        db.session.commit()

    body = auth_client.get("/api/v1/trends/narrative?period=week").get_json()
    assert body["deltas"]["days_logged"] == 3
    assert round(body["deltas"]["avg_sleep"], 1) == 1.7
    assert body["momentum"]["label"] == "building"
    assert any("146/92" in r for r in body["risks"])
    assert any("108" in r for r in body["risks"])
    assert any("2.4 kg" in r for r in body["risks"])
    assert any("water" in r.lower() for r in body["recommendations"])
    assert len(body["recommendations"]) <= 3
    assert any("vital" in a.lower() for a in body["achievements"])
