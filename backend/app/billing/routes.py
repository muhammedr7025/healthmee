from flask import current_app, request
from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.billing import service
from app.billing.schemas import (
    CheckoutRequestSchema,
    CheckoutResponseSchema,
    PortalRequestSchema,
    PortalResponseSchema,
    SubscriptionSchema,
)

blp = Blueprint("billing", __name__, url_prefix="/api/v1/billing", description="Subscriptions & billing (Stripe)")


@blp.route("/subscription")
class SubscriptionView(MethodView):
    @jwt_required()
    @blp.response(200, SubscriptionSchema)
    def get(self):
        return service.get_or_create_subscription(get_jwt_identity()).to_dict()


@blp.route("/checkout-session")
class CheckoutSession(MethodView):
    @jwt_required()
    @blp.arguments(CheckoutRequestSchema)
    @blp.response(201, CheckoutResponseSchema)
    def post(self, data):
        user = User.query.get_or_404(get_jwt_identity())
        return service.start_checkout(user, data.get("success_url"), data.get("cancel_url"))


@blp.route("/portal-session")
class PortalSession(MethodView):
    """Mock mode: immediately downgrades to free (a stand-in for "manage /
    cancel subscription", since there's no real Stripe customer to portal
    into). Real mode: returns a Stripe-hosted billing portal URL.
    """

    @jwt_required()
    @blp.arguments(PortalRequestSchema)
    @blp.response(201, PortalResponseSchema)
    def post(self, data):
        user = User.query.get_or_404(get_jwt_identity())
        return service.start_portal_session(user, data.get("return_url"))


@blp.route("/webhook")
class StripeWebhook(MethodView):
    """Stripe calls this directly — no JWT, verified by signature instead."""

    def post(self):
        webhook_secret = current_app.config.get("STRIPE_WEBHOOK_SECRET")
        if not webhook_secret:
            abort(501, message="Stripe webhook not configured (running in mock billing mode).")

        import stripe

        payload = request.get_data()
        sig_header = request.headers.get("Stripe-Signature", "")
        try:
            event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
        except (ValueError, stripe.error.SignatureVerificationError):
            abort(400, message="Invalid Stripe webhook signature.")

        service.handle_stripe_event(event)
        return {"received": True}
