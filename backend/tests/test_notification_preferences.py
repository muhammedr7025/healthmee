def test_defaults_to_all_enabled(auth_client):
    resp = auth_client.get("/api/v1/notification-preferences")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body == {"medication_reminders": True, "quiet_nudges": True, "streak_milestones": True}


def test_patch_updates_a_single_toggle(auth_client):
    resp = auth_client.patch("/api/v1/notification-preferences", json={"quiet_nudges": False})
    assert resp.status_code == 200
    assert resp.get_json()["quiet_nudges"] is False
    assert resp.get_json()["medication_reminders"] is True

    resp = auth_client.get("/api/v1/notification-preferences")
    assert resp.get_json()["quiet_nudges"] is False
