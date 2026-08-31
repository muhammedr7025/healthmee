from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class MedicalProfile(db.Model, TimestampMixin):
    """Versioned: every edit inserts a new row and flips is_current, so the
    full history of changes is preserved (dev-prompt §4 — Medical Profile is
    'editable, versioned, shows history of changes').
    """

    __tablename__ = "medical_profiles"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    version = db.Column(db.Integer, nullable=False, default=1)
    is_current = db.Column(db.Boolean, nullable=False, default=True, index=True)

    conditions = db.Column(db.JSON, nullable=False, default=list)  # e.g. ["pre-diabetes", "hypertension"]
    medications = db.Column(db.JSON, nullable=False, default=list)
    baseline_vitals = db.Column(db.JSON, nullable=False, default=dict)  # height_cm, weight_kg, resting_hr, bp
    notes = db.Column(db.Text, nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "version": self.version,
            "conditions": self.conditions,
            "medications": self.medications,
            "baseline_vitals": self.baseline_vitals,
            "notes": self.notes,
            "created_at": self.created_at.isoformat(),
        }


class Allergy(db.Model, TimestampMixin):
    __tablename__ = "allergies"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    name = db.Column(db.String(255), nullable=False)
    severity = db.Column(db.String(20), nullable=False, default="moderate")  # mild|moderate|severe
    notes = db.Column(db.Text, nullable=True)

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name, "severity": self.severity, "notes": self.notes}


class LabResult(db.Model, TimestampMixin):
    __tablename__ = "lab_results"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    source = db.Column(db.String(20), nullable=False, default="manual")  # ocr|manual
    test_name = db.Column(db.String(255), nullable=False)
    value = db.Column(db.String(64), nullable=False)
    unit = db.Column(db.String(32), nullable=True)
    reference_range = db.Column(db.String(64), nullable=True)
    taken_at = db.Column(db.DateTime, nullable=False)
    media_asset_id = db.Column(db.String(36), db.ForeignKey("media_assets.id"), nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "source": self.source,
            "test_name": self.test_name,
            "value": self.value,
            "unit": self.unit,
            "reference_range": self.reference_range,
            "taken_at": self.taken_at.isoformat(),
            "media_asset_id": self.media_asset_id,
        }
