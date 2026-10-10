import re
from datetime import datetime, timedelta

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider

MOOD_WORDS = {
    "happy": ["happy", "great", "good", "energetic", "excited"],
    "sad": ["sad", "down", "low", "depressed"],
    "stressed": ["stressed", "anxious", "overwhelmed", "tense"],
    "calm": ["calm", "relaxed", "peaceful"],
    "tired": ["tired", "exhausted", "sleepy", "drained"],
}

ACTIVITY_WORDS = ["walk", "run", "gym", "workout", "yoga", "swim", "cycle", "cycling", "jog"]

SLEEP_RE = re.compile(r"slept?\s+(\d+(?:\.\d+)?)\s*h(?:ours?|rs?)?", re.IGNORECASE)
FOOD_LEAD_WORDS = ["ate", "had", "eating", "breakfast", "lunch", "dinner", "snack", "drank"]

# "had"/"drank" alone shouldn't also log a meal when the message is just about
# a drink — only these imply actual food.
SOLID_FOOD_WORDS = ["ate", "eating", "breakfast", "lunch", "dinner", "snack"]

DRINK_WORDS = ["water", "juice", "tea", "coffee", "milk", "buttermilk", "smoothie"]
VOLUME_RE = re.compile(
    r"(\d+(?:\.\d+)?)\s*(ml\b|milliliters?|millilitres?|l\b|litres?|liters?|glass(?:es)?|cups?|bottles?)",
    re.IGNORECASE,
)
_UNIT_ML = {"glass": 250, "cup": 240, "bottle": 500, "l": 1000, "litre": 1000, "liter": 1000, "ml": 1}
_DEFAULT_SERVING_ML = 250  # a plain "drank water" with no quantity = one glass

# "at 7pm", "7:30 am", "19:00"
_CLOCK_RE = re.compile(r"\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\b(\d{1,2}):(\d{2})\b", re.IGNORECASE)
# Same defaults the LLM prompt is given, so mock and real modes agree.
_TIME_OF_DAY_HOURS = {"breakfast": 8, "morning": 8, "lunch": 13, "afternoon": 15, "evening": 18, "dinner": 20}

# Vitals. Each wants the number within a short run of non-digits after the
# cue word, so "weight is 72 kg" matches but "2 spoons of sugar" doesn't.
_BP_RE = re.compile(r"(?:\bbp\b|blood pressure|pressure)\D{0,12}?(\d{2,3})\s*(?:/|over)\s*(\d{2,3})|\b(\d{2,3})\s*/\s*(\d{2,3})\b")
_GLUCOSE_RE = re.compile(r"(?:blood sugar|sugar|glucose|\bfbs\b|\bppbs\b|\brbs\b)\D{0,15}?(\d{1,3}(?:\.\d+)?)")
# "after lunch", "before dinner": the meal is a time marker, not something eaten.
_MEAL_AS_TIME_RE = re.compile(r"\b(?:after|before|post|pre|since|until|till)\s+(?:my\s+)?(?:breakfast|lunch|dinner|meals?|food|eating)\b")
_WEIGHT_RE = re.compile(r"(?:weight|weigh(?:ed|s|ing)?)\D{0,12}?(\d{2,3}(?:\.\d+)?)\s*(kgs?|kilos?|lbs?|pounds?)?")
_HR_RE = re.compile(r"(?:heart ?rate|pulse|\bhr\b)\D{0,12}?(\d{2,3})")
_SPO2_RE = re.compile(r"(?:spo2|oxygen(?: saturation| level)?|\bo2\b)\D{0,12}?(\d{2,3})")
_TEMP_RE = re.compile(r"(?:temperature|\btemp\b|fever)\D{0,12}?(\d{2,3}(?:\.\d)?)")
_POST_MEAL_RE = re.compile(r"after (?:food|eating|a meal|meals?|lunch|dinner|breakfast)|post[- ]?meal|post[- ]?prandial|\bpp\b")
_VITAL_UNITS = {
    "blood_pressure": "mmHg",
    "blood_glucose": "mg/dL",
    "weight": "kg",
    "heart_rate": "bpm",
    "spo2": "%",
    "temperature": "°C",
}


def _has_word(text: str, word: str) -> bool:
    """Matches at a word start, so "run" still catches "running" but "ate"
    no longer fires inside "w-ate-r" — which was making every water message
    log a phantom meal alongside it.
    """
    return re.search(rf"\b{re.escape(word)}", text) is not None


def _describes_eating(lowered: str) -> bool:
    """Whether the message says something was eaten, as opposed to merely
    naming a meal as a point in time ("sugar 110 after lunch")."""
    if any(_has_word(lowered, word) for word in ("ate", "eating", "snack")):
        return True
    without_time_markers = _MEAL_AS_TIME_RE.sub(" ", lowered)
    return any(_has_word(without_time_markers, meal) for meal in ("breakfast", "lunch", "dinner"))


class MockProvider(LLMProvider):
    """Deterministic keyword-based extractor used when no LLM API key is
    configured, so the extraction pipeline is fully exercisable offline.
    """

    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
        local_now: datetime | None = None,
    ) -> ExtractionResult:
        lowered = text.lower()
        entries: list[ExtractedEntry] = []

        hydration = self._hydration(lowered)
        if hydration is not None:
            entries.append(hydration)

        vitals = self._vitals(lowered)
        entries.extend(vitals)

        # A drink-only message ("drank 2 glasses of water") or a reading
        # ("had bp 120/80 this morning", "sugar 6.1 after lunch") shouldn't
        # also create a food entry just because "drank"/"had"/"lunch" appears.
        logs_food = any(_has_word(lowered, word) for word in FOOD_LEAD_WORDS) and (
            (hydration is None and not vitals) or _describes_eating(lowered)
        )
        if logs_food:
            entries.append(
                ExtractedEntry(
                    type="food",
                    payload={"food_items": [text.strip()], "meal_type": self._meal_type(lowered)},
                    summary=text.strip()[:80],
                )
            )

        sleep_match = SLEEP_RE.search(lowered)
        if sleep_match:
            hours = float(sleep_match.group(1))
            entries.append(
                ExtractedEntry(
                    type="sleep",
                    payload={"hours": hours},
                    summary=f"Slept {hours}h",
                )
            )

        for mood, keywords in MOOD_WORDS.items():
            if any(_has_word(lowered, k) for k in keywords):
                entries.append(
                    ExtractedEntry(type="mood", payload={"mood": mood}, summary=f"Feeling {mood}")
                )
                break

        if any(_has_word(lowered, word) for word in ACTIVITY_WORDS):
            entries.append(
                ExtractedEntry(
                    type="activity",
                    payload={"activity_type": self._activity_type(lowered), "raw_text": text.strip()},
                    summary=text.strip()[:80],
                )
            )

        if not entries:
            if image_bytes is not None:
                return ExtractionResult(
                    entries=[],
                    reply="I can see a photo came through, but I'm running without a real AI connected "
                    "right now, so I can't tell what's in it. Describe it in words and I'll log it.",
                )
            return ExtractionResult(
                entries=[],
                reply="Got it — I couldn't quite tell what to log from that. Could you say a bit more?",
            )

        occurred_at = self._occurred_at(lowered, local_now)
        if occurred_at is not None:
            for entry in entries:
                if entry.type != "sleep":  # a night's sleep belongs to the morning after — stays "now"
                    entry.occurred_at = occurred_at

        summaries = "; ".join(e.summary for e in entries)
        return ExtractionResult(entries=entries, reply=f"Logged: {summaries}")

    @staticmethod
    def _occurred_at(lowered: str, local_now: datetime | None) -> str | None:
        """Resolves "yesterday"/"for dinner"/"at 7pm" against the user's local
        clock — the same rules the real providers are prompted with, so
        offline mode logs to the same moment the LLM would."""
        if local_now is None:
            return None

        day_shift = 0
        if "day before yesterday" in lowered:
            day_shift = -2
        elif _has_word(lowered, "yesterday"):
            day_shift = -1

        hour = minute = None
        clock = _CLOCK_RE.search(lowered)
        if clock:
            if clock.group(1):
                hour = int(clock.group(1)) % 12 + (12 if clock.group(3).lower() == "pm" else 0)
                minute = int(clock.group(2) or 0)
            else:
                hour, minute = int(clock.group(4)), int(clock.group(5))
        else:
            for word, h in _TIME_OF_DAY_HOURS.items():
                if _has_word(lowered, word):
                    hour, minute = h, 0
                    break

        if day_shift == 0 and hour is None:
            return None  # nothing said when — it's now
        if hour is None:
            hour, minute = local_now.hour, local_now.minute  # "yesterday", same clock time
        when = (local_now + timedelta(days=day_shift)).replace(hour=hour, minute=minute, second=0, microsecond=0)
        return when.isoformat(timespec="minutes")

    @staticmethod
    def _hydration(lowered: str) -> ExtractedEntry | None:
        """Fluid intake, so the Today/Trends water stat has something real to
        aggregate. Quantities are converted with conventional serving sizes
        (a glass = 250ml); a drink with no stated amount counts as one glass.
        """
        beverage = next((d for d in DRINK_WORDS if _has_word(lowered, d)), None)
        if beverage is None:
            return None

        match = VOLUME_RE.search(lowered)
        if match:
            amount = float(match.group(1))
            unit = match.group(2).lower().rstrip("s").rstrip(".")
            unit = {"milliliter": "ml", "millilitre": "ml", "glasse": "glass"}.get(unit, unit)
            volume_ml = amount * _UNIT_ML.get(unit, _DEFAULT_SERVING_ML)
        else:
            # No amount given — only assume a serving if they clearly drank
            # something, rather than merely mentioning it.
            if not any(_has_word(lowered, verb) for verb in ("drank", "drink", "had", "sipping", "sipped")):
                return None
            volume_ml = _DEFAULT_SERVING_ML

        volume_ml = round(volume_ml)
        return ExtractedEntry(
            type="hydration",
            payload={"volume_ml": volume_ml, "beverage": beverage},
            summary=f"{volume_ml} ml {beverage}",
        )

    @staticmethod
    def _vitals(lowered: str) -> list[ExtractedEntry]:
        """BP, sugar, weight, pulse, SpO2, temperature — the readings people
        type after a home check or a clinic visit. Sanity ranges keep a date
        like 10/11 from becoming a blood pressure."""
        context = None
        if "fasting" in lowered:
            context = "fasting"
        elif _POST_MEAL_RE.search(lowered):
            context = "post_meal"
        elif "resting" in lowered:
            context = "resting"
        elif _has_word(lowered, "bedtime") or "before bed" in lowered:
            context = "bedtime"
        elif _has_word(lowered, "morning"):
            context = "morning"

        def entry(kind, value, summary, diastolic=None, unit=None):
            payload = {"kind": kind, "value": value, "unit": unit or _VITAL_UNITS[kind]}
            if diastolic is not None:
                payload["diastolic"] = diastolic
            if context:
                payload["context"] = context
            return ExtractedEntry(type="vital", payload=payload, summary=summary)

        found: list[ExtractedEntry] = []

        bp = _BP_RE.search(lowered)
        if bp:
            systolic = int(bp.group(1) or bp.group(3))
            diastolic = int(bp.group(2) or bp.group(4))
            if 70 <= systolic <= 250 and 40 <= diastolic <= 150:
                found.append(entry("blood_pressure", systolic, f"BP {systolic}/{diastolic} mmHg", diastolic=diastolic))

        glucose = _GLUCOSE_RE.search(lowered)
        if glucose:
            value = float(glucose.group(1))
            if value < 30:  # only mmol/L reads that low
                found.append(entry("blood_glucose", value, f"Blood sugar {value:g} mmol/L", unit="mmol/L"))
            elif value <= 600:
                suffix = f" ({context.replace('_', ' ')})" if context in ("fasting", "post_meal") else ""
                found.append(entry("blood_glucose", value, f"Blood sugar {value:g} mg/dL{suffix}"))

        weight = _WEIGHT_RE.search(lowered)
        if weight:
            value = float(weight.group(1))
            unit = "lb" if (weight.group(2) or "").startswith(("lb", "pound")) else "kg"
            if 20 <= value <= 400:
                found.append(entry("weight", value, f"Weight {value:g} {unit}", unit=unit))

        hr = _HR_RE.search(lowered)
        if hr and 30 <= int(hr.group(1)) <= 220:
            found.append(entry("heart_rate", int(hr.group(1)), f"Heart rate {hr.group(1)} bpm"))

        spo2 = _SPO2_RE.search(lowered)
        if spo2 and 50 <= int(spo2.group(1)) <= 100:
            found.append(entry("spo2", int(spo2.group(1)), f"SpO2 {spo2.group(1)}%"))

        temp = _TEMP_RE.search(lowered)
        if temp:
            value = float(temp.group(1))
            if 34 <= value <= 43:
                found.append(entry("temperature", value, f"Temperature {value:g} °C"))
            elif 93 <= value <= 110:
                found.append(entry("temperature", value, f"Temperature {value:g} °F", unit="°F"))

        return found

    @staticmethod
    def _meal_type(lowered: str) -> str:
        for meal in ("breakfast", "lunch", "dinner", "snack"):
            if _has_word(lowered, meal):
                return meal
        return "snack"

    @staticmethod
    def _activity_type(lowered: str) -> str:
        for word in ACTIVITY_WORDS:
            if _has_word(lowered, word):
                return word
        return "activity"
