from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class NarrativeCache(db.Model, TimestampMixin):
    """One row per user per period holding the last generated Trends summary
    and a fingerprint of the stats it was written from. Regenerated only when
    the numbers actually change — the free Gemini tier is 500 requests/day,
    and tab-switching would otherwise spend it re-writing identical prose.
    """

    __tablename__ = "narrative_cache"
    __table_args__ = (db.UniqueConstraint("user_id", "period", name="uq_narrative_cache_user_period"),)

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    period = db.Column(db.String(20), nullable=False)
    stats_fingerprint = db.Column(db.String(64), nullable=False)
    summary = db.Column(db.Text, nullable=False)


class DailyAggregate(db.Model, TimestampMixin):
    __tablename__ = "daily_aggregates"
    __table_args__ = (db.UniqueConstraint("user_id", "date", name="uq_daily_aggregate_user_date"),)

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    date = db.Column(db.Date, nullable=False, index=True)

    total_calories = db.Column(db.Float, nullable=False, default=0)
    activity_minutes = db.Column(db.Float, nullable=False, default=0)
    sleep_hours = db.Column(db.Float, nullable=True)
    mood_score = db.Column(db.Float, nullable=True)
    water_ml = db.Column(db.Float, nullable=False, default=0)
    log_count = db.Column(db.Integer, nullable=False, default=0)

    def to_dict(self) -> dict:
        return {
            "date": self.date.isoformat(),
            "total_calories": self.total_calories,
            "activity_minutes": self.activity_minutes,
            "sleep_hours": self.sleep_hours,
            "mood_score": self.mood_score,
            "water_ml": self.water_ml,
            "log_count": self.log_count,
        }
