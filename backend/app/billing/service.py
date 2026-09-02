"""Billing service: mock mode (no Stripe key — flips plans instantly, no
network calls, fully offline-testable) vs real Stripe Checkout + webhooks.
Same pluggable-provider shape as app/common/llm/factory.py.
"""

from datetime import datetime, timedelta, timezone

from flask import current_app

from app.billing.models import Subscription
from app.extensions import db


def get_or_create_subscription(user_id: str) -> Subscription:
    sub = Subscription.query.filter_by(user_id=user_id).first()
    if sub is None:
        sub = Subscription(user_id=user_id, plan="free", status="none", billing_mode=_mode())
        db.session.add(sub)
        db.session.commit()
    return sub


def is_premium(user_id: str) -> bool:
    sub = Subscription.query.filter_by(user_id=user_id).first()
    if sub is None:
        return False
    return sub.plan == "premium" and sub.status in ("active", "trialing")


def _mode() -> str:
    return "stripe" if current_app.config.get("STRIPE_SECRET_KEY") else "mock"


def start_checkout(user, success_url: str | None = None, cancel_url: str | None = None) -> dict:
    sub = get_or_create_subscription(user.id)

    if _mode() == "mock":
        sub.plan = "premium"
        sub.status = "active"
        sub.billing_mode = "mock"
        sub.current_period_end = datetime.now(timezone.utc) + timedelta(days=30)
        sub.cancel_at_period_end = False
        db.session.commit()
        return {"mode": "mock", "checkout_url": None, "subscription": sub.to_dict()}

    import stripe

    stripe.api_key = current_app.config["STRIPE_SECRET_KEY"]

    if not sub.stripe_customer_id:
        customer = stripe.Customer.create(email=user.email, name=user.full_name or None)
        sub.stripe_customer_id = customer["id"]
        db.session.commit()

    session = stripe.checkout.Session.create(
        mode="subscription",
        customer=sub.stripe_customer_id,
        line_items=[{"price": current_app.config["STRIPE_PRICE_ID"], "quantity": 1}],
        success_url=success_url or current_app.config["BILLING_SUCCESS_URL"],
        cancel_url=cancel_url or current_app.config["BILLING_CANCEL_URL"],
        client_reference_id=user.id,
    )
    return {"mode": "stripe", "checkout_url": session["url"], "subscription": sub.to_dict()}


def start_portal_session(user, return_url: str | None = None) -> dict:
    sub = get_or_create_subscription(user.id)

    if _mode() == "mock" or not sub.stripe_customer_id:
        sub.plan = "free"
        sub.status = "canceled"
        db.session.commit()
        return {"mode": "mock", "portal_url": None, "subscription": sub.to_dict()}

    import stripe

    stripe.api_key = current_app.config["STRIPE_SECRET_KEY"]
    session = stripe.billing_portal.Session.create(
        customer=sub.stripe_customer_id,
        return_url=return_url or current_app.config["BILLING_SUCCESS_URL"],
    )
    return {"mode": "stripe", "portal_url": session["url"], "subscription": sub.to_dict()}


def handle_stripe_event(event: dict) -> None:
    """Applies a verified Stripe webhook event to our Subscription rows."""
    event_type = event["type"]
    obj = event["data"]["object"]

    if event_type == "checkout.session.completed":
        user_id = obj.get("client_reference_id")
        sub = Subscription.query.filter_by(user_id=user_id).first() if user_id else None
        if sub is None and obj.get("customer"):
            sub = Subscription.query.filter_by(stripe_customer_id=obj["customer"]).first()
        if sub:
            sub.stripe_customer_id = obj.get("customer") or sub.stripe_customer_id
            sub.stripe_subscription_id = obj.get("subscription") or sub.stripe_subscription_id
            sub.plan = "premium"
            sub.status = "active"
            sub.billing_mode = "stripe"
            db.session.commit()

    elif event_type in ("customer.subscription.updated", "customer.subscription.created"):
        sub = Subscription.query.filter_by(stripe_customer_id=obj.get("customer")).first()
        if sub:
            sub.stripe_subscription_id = obj.get("id") or sub.stripe_subscription_id
            sub.status = _map_stripe_status(obj.get("status"))
            sub.plan = "premium" if sub.status in ("active", "trialing") else "free"
            sub.cancel_at_period_end = bool(obj.get("cancel_at_period_end"))
            period_end = obj.get("current_period_end")
            if period_end:
                sub.current_period_end = datetime.fromtimestamp(period_end, tz=timezone.utc)
            db.session.commit()

    elif event_type == "customer.subscription.deleted":
        sub = Subscription.query.filter_by(stripe_customer_id=obj.get("customer")).first()
        if sub:
            sub.plan = "free"
            sub.status = "canceled"
            db.session.commit()


def _map_stripe_status(stripe_status: str | None) -> str:
    return {
        "active": "active",
        "trialing": "trialing",
        "past_due": "past_due",
        "canceled": "canceled",
        "unpaid": "past_due",
        "incomplete_expired": "canceled",
    }.get(stripe_status or "", "none")
