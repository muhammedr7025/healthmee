from datetime import datetime, timezone

from flask import current_app

from app.logging.models import ChatMessage
from app.media.models import MediaAsset
from app.media.storage import presign_download


def get_chat_history(user_id: str, limit: int) -> dict:
    """Reconstructs the chat thread from persisted rows, oldest first (how
    the thread renders on screen), plus a "welcome back" greeting when the
    user's been away long enough that MiMi should say something about it.
    """
    rows = (
        ChatMessage.query.filter_by(user_id=user_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    rows.reverse()

    items = []
    for row in rows:
        data = row.to_dict()
        if row.kind == "user_photo" and row.media_asset_id:
            asset = MediaAsset.query.get(row.media_asset_id)
            if asset:
                # Longer than the upload presign: someone reopening the app
                # to read old messages shouldn't have images expire mid-scroll.
                data["photo_url"] = presign_download(asset.storage_key, expires_in=3600)
        items.append(data)

    last_activity = rows[-1].created_at if rows else None
    return {"items": items, "welcome_back_message": _welcome_back_message(last_activity)}


def _welcome_back_message(last_activity: datetime | None) -> str | None:
    if last_activity is None:
        return None
    if last_activity.tzinfo is None:
        last_activity = last_activity.replace(tzinfo=timezone.utc)

    hours_idle = (datetime.now(timezone.utc) - last_activity).total_seconds() / 3600
    if hours_idle < current_app.config["CHAT_IDLE_GREETING_HOURS"]:
        return None
    if hours_idle < 12:
        return (
            "Hey — it's been a few hours since we last talked. Did you get to eat "
            "something, or grab a bit of rest? We missed you."
        )
    if hours_idle < 24:
        return (
            "It's been most of a day since we last heard from you. Did you eat, "
            "drink enough water, or get some proper sleep? We missed you."
        )
    return (
        "It's been a while since we last talked. Hope you've been eating, resting, "
        "and taking care of yourself. We missed you."
    )
