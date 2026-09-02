from marshmallow import Schema, fields


class SubscriptionSchema(Schema):
    plan = fields.String(dump_only=True)
    status = fields.String(dump_only=True)
    billing_mode = fields.String(dump_only=True)
    is_premium = fields.Boolean(dump_only=True)
    current_period_end = fields.String(dump_only=True, allow_none=True)
    cancel_at_period_end = fields.Boolean(dump_only=True)


class CheckoutRequestSchema(Schema):
    success_url = fields.String(required=False, allow_none=True)
    cancel_url = fields.String(required=False, allow_none=True)


class CheckoutResponseSchema(Schema):
    mode = fields.String(dump_only=True)
    checkout_url = fields.String(dump_only=True, allow_none=True)
    subscription = fields.Nested(SubscriptionSchema, dump_only=True)


class PortalRequestSchema(Schema):
    return_url = fields.String(required=False, allow_none=True)


class PortalResponseSchema(Schema):
    mode = fields.String(dump_only=True)
    portal_url = fields.String(dump_only=True, allow_none=True)
    subscription = fields.Nested(SubscriptionSchema, dump_only=True)
