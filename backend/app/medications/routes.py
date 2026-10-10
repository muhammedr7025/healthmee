from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.common.localtime import local_today, user_tz_offset
from app.common.models import utcnow
from app.extensions import db
from app.medications.models import MedicationDose, MedicationSchedule
from app.medications.schemas import (
    DayPlanSchema,
    DoseMarkSchema,
    MedicationScheduleSchema,
    MedicationScheduleUpdateSchema,
)
from app.medications.service import day_plan, due_slots

blp = Blueprint("medications", __name__, url_prefix="/api/v1/medications", description="Medicine schedules & adherence")


def _today(user: User):
    return local_today(user_tz_offset(user))


@blp.route("")
class Medications(MethodView):
    @jwt_required()
    @blp.response(200, MedicationScheduleSchema(many=True))
    def get(self):
        return (
            MedicationSchedule.query.filter_by(user_id=get_jwt_identity())
            .order_by(MedicationSchedule.active.desc(), MedicationSchedule.created_at.asc())
            .all()
        )

    @jwt_required()
    @blp.arguments(MedicationScheduleSchema)
    @blp.response(201, MedicationScheduleSchema)
    def post(self, data):
        schedule = MedicationSchedule(user_id=get_jwt_identity(), **data)
        schedule.times = sorted(set(schedule.times))
        db.session.add(schedule)
        db.session.commit()
        return schedule


@blp.route("/today")
class MedicationsToday(MethodView):
    @jwt_required()
    @blp.response(200, DayPlanSchema)
    def get(self):
        user = User.query.get_or_404(get_jwt_identity())
        return day_plan(user.id, _today(user))


@blp.route("/<string:schedule_id>")
class MedicationDetail(MethodView):
    @jwt_required()
    @blp.arguments(MedicationScheduleUpdateSchema)
    @blp.response(200, MedicationScheduleSchema)
    def patch(self, data, schedule_id):
        schedule = MedicationSchedule.query.filter_by(id=schedule_id, user_id=get_jwt_identity()).first_or_404()
        for key, value in data.items():
            setattr(schedule, key, sorted(set(value)) if key == "times" else value)
        db.session.commit()
        return schedule

    @jwt_required()
    @blp.response(204)
    def delete(self, schedule_id):
        schedule = MedicationSchedule.query.filter_by(id=schedule_id, user_id=get_jwt_identity()).first_or_404()
        MedicationDose.query.filter_by(schedule_id=schedule.id).delete()
        db.session.delete(schedule)
        db.session.commit()


@blp.route("/<string:schedule_id>/doses")
class MedicationDoses(MethodView):
    """Mark one slot taken/skipped (or back to pending). Idempotent per
    slot — tapping twice flips, it doesn't double-count."""

    @jwt_required()
    @blp.arguments(DoseMarkSchema)
    @blp.response(200, DayPlanSchema)
    def post(self, data, schedule_id):
        user = User.query.get_or_404(get_jwt_identity())
        schedule = MedicationSchedule.query.filter_by(id=schedule_id, user_id=user.id).first_or_404()
        day = data.get("date") or _today(user)
        if data["time"] not in due_slots(schedule, day):
            abort(422, message=f"{schedule.name} isn't due at {data['time']} on {day.isoformat()}.")

        mark = MedicationDose.query.filter_by(
            schedule_id=schedule.id, scheduled_date=day, scheduled_time=data["time"]
        ).first()
        if data["status"] == "pending":
            if mark is not None:
                db.session.delete(mark)
        elif mark is None:
            db.session.add(
                MedicationDose(
                    user_id=user.id,
                    schedule_id=schedule.id,
                    scheduled_date=day,
                    scheduled_time=data["time"],
                    status=data["status"],
                    marked_at=utcnow(),
                )
            )
        else:
            mark.status = data["status"]
            mark.marked_at = utcnow()
        db.session.commit()
        return day_plan(user.id, day)
