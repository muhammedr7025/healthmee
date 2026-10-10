"""Medicines as a schedule plus a tick per dose, so Today can show "2 of 3
taken" rather than the free-text list the medical profile keeps.
MedicalProfile.medications stays as the "what I take" record; this is the
"did I take it today" layer on top.
"""

from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class MedicationSchedule(db.Model, TimestampMixin):
    __tablename__ = "medication_schedules"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    name = db.Column(db.String(255), nullable=False)
    dose = db.Column(db.String(64), nullable=True)  # "500 mg", "1 tablet"
    times = db.Column(db.JSON, nullable=False, default=list)  # ["08:00", "20:00"] local wall-clock
    days_of_week = db.Column(db.JSON, nullable=True)  # [0..6] Monday=0, or null for every day
    active = db.Column(db.Boolean, nullable=False, default=True)
    notes = db.Column(db.Text, nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "dose": self.dose,
            "times": self.times or [],
            "days_of_week": self.days_of_week,
            "active": self.active,
            "notes": self.notes,
        }


class MedicationDose(db.Model, TimestampMixin):
    """One row per (schedule, local day, slot) once the user has marked it.
    No row means pending — the plan for a day is derived from the schedule,
    not pre-generated, so adding a medicine shows up immediately."""

    __tablename__ = "medication_doses"
    __table_args__ = (
        db.UniqueConstraint("schedule_id", "scheduled_date", "scheduled_time", name="uq_medication_dose_slot"),
    )

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    schedule_id = db.Column(
        db.String(36), db.ForeignKey("medication_schedules.id", ondelete="CASCADE"), nullable=False, index=True
    )
    scheduled_date = db.Column(db.Date, nullable=False, index=True)  # the user's local day
    scheduled_time = db.Column(db.String(5), nullable=False)  # "HH:MM"
    status = db.Column(db.String(10), nullable=False)  # taken|skipped
    marked_at = db.Column(db.DateTime, nullable=False)
