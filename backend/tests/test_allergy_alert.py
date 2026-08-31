def test_food_matching_allergy_triggers_alert(auth_client):
    auth_client.post("/api/v1/allergies", json={"name": "peanut", "severity": "severe"})

    resp = auth_client.post(
        "/api/v1/chat/messages", json={"text": "ate a peanut butter sandwich for lunch"}
    )
    data = resp.get_json()

    assert data["alerts"]
    assert data["alerts"][0]["trigger_type"] == "allergy"
    assert data["alerts"][0]["severity"] == "hard"


def test_food_without_allergy_match_has_no_alert(auth_client):
    auth_client.post("/api/v1/allergies", json={"name": "shellfish", "severity": "severe"})

    resp = auth_client.post("/api/v1/chat/messages", json={"text": "had rice and lentils for dinner"})
    data = resp.get_json()

    assert data["alerts"] == []
