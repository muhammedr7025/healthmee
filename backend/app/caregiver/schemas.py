from marshmallow import Schema, fields


class CaregiverLinkSchema(Schema):
    id = fields.String(dump_only=True)
    owner_user_id = fields.String(dump_only=True)
    caregiver_user_id = fields.String(dump_only=True, allow_none=True)
    caregiver_email = fields.Email(dump_only=True)
    status = fields.String(dump_only=True)
    can_view_logs = fields.Boolean(dump_only=True)
    can_view_trends_reports = fields.Boolean(dump_only=True)
    can_edit_profile = fields.Boolean(dump_only=True)
    created_at = fields.String(dump_only=True)

    # denormalized, filled in by the route for /access (caregiver's own list)
    owner_email = fields.String(dump_only=True)
    owner_full_name = fields.String(dump_only=True, allow_none=True)


class InviteCaregiverSchema(Schema):
    email = fields.Email(required=True)
    can_view_logs = fields.Boolean(required=False, load_default=True)
    can_view_trends_reports = fields.Boolean(required=False, load_default=True)
    can_edit_profile = fields.Boolean(required=False, load_default=False)


class UpdateCaregiverPermissionsSchema(Schema):
    can_view_logs = fields.Boolean(required=False)
    can_view_trends_reports = fields.Boolean(required=False)
    can_edit_profile = fields.Boolean(required=False)


class CaregiverSummarySchema(Schema):
    owner_user_id = fields.String(dump_only=True)
    owner_email = fields.Email(dump_only=True)
    owner_full_name = fields.String(dump_only=True, allow_none=True)
    medical_profile = fields.Dict(dump_only=True, allow_none=True)
    recent_logs = fields.List(fields.Dict(), dump_only=True)
    permissions = fields.Dict(dump_only=True)
