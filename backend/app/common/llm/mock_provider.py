import re

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


def _has_word(text: str, word: str) -> bool:
    """Matches at a word start, so "run" still catches "running" but "ate"
    no longer fires inside "w-ate-r" — which was making every water message
    log a phantom meal alongside it.
    """
    return re.search(rf"\b{re.escape(word)}", text) is not None


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
    ) -> ExtractionResult:
        lowered = text.lower()
        entries: list[ExtractedEntry] = []

        hydration = self._hydration(lowered)
        if hydration is not None:
            entries.append(hydration)

        # A drink-only message ("drank 2 glasses of water") shouldn't also
        # create a food entry just because "drank"/"had" appears.
        logs_food = any(_has_word(lowered, word) for word in FOOD_LEAD_WORDS) and (
            hydration is None or any(_has_word(lowered, word) for word in SOLID_FOOD_WORDS)
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

        summaries = "; ".join(e.summary for e in entries)
        return ExtractionResult(entries=entries, reply=f"Logged: {summaries}")

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
