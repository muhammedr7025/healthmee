from marshmallow import Schema, fields


class GenerateReportRequestSchema(Schema):
    start = fields.Date(required=False, allow_none=True)
    end = fields.Date(required=False, allow_none=True)


class GeneratedReportSchema(Schema):
    id = fields.String(dump_only=True)
    range_start = fields.String(dump_only=True)
    range_end = fields.String(dump_only=True)
    page_count = fields.Integer(dump_only=True)
    created_at = fields.String(dump_only=True)


class GeneratedReportWithUrlSchema(GeneratedReportSchema):
    download_url = fields.String(dump_only=True)
    expires_in_seconds = fields.Integer(dump_only=True)
