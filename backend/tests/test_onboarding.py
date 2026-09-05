def test_onboarding_sets_full_name_and_completes_profile(auth_client):
    resp = auth_client.post(
        "/api/v1/onboarding",
        json={
            "full_name": "Anand",
            "conditions": ["Hypertension"],
            "medications": [],
            "allergies": [{"name": "Peanut", "severity": "severe"}],
            "baseline_vitals": {"age": 34},
            "goals": [],
            "consent_given": True,
        },
    )
    assert resp.status_code == 201

    me = auth_client.get("/api/v1/auth/me")
    assert me.get_json()["full_name"] == "Anand"
    assert me.get_json()["onboarding_completed"] is True


def test_onboarding_without_full_name_leaves_it_unset(auth_client):
    resp = auth_client.post(
        "/api/v1/onboarding",
        json={"conditions": [], "medications": [], "allergies": [], "baseline_vitals": {}, "goals": [], "consent_given": True},
    )
    assert resp.status_code == 201

    me = auth_client.get("/api/v1/auth/me")
    assert me.get_json()["full_name"] is None
