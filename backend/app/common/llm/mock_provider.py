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


class MockProvider(LLMProvider):
    """Deterministic keyword-based extractor used when no LLM API key is
    configured, so the extraction pipeline is fully exercisable offline.
    """

    def extract(self, text: str, type_catalog: list[dict]) -> ExtractionResult:
        lowered = text.lower()
        entries: list[ExtractedEntry] = []

        if any(word in lowered for word in FOOD_LEAD_WORDS):
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
            if any(k in lowered for k in keywords):
                entries.append(
                    ExtractedEntry(type="mood", payload={"mood": mood}, summary=f"Feeling {mood}")
                )
                break

        if any(word in lowered for word in ACTIVITY_WORDS):
            entries.append(
                ExtractedEntry(
                    type="activity",
                    payload={"activity_type": self._activity_type(lowered), "raw_text": text.strip()},
                    summary=text.strip()[:80],
                )
            )

        if not entries:
            return ExtractionResult(
                entries=[],
                reply="Got it — I couldn't quite tell what to log from that. Could you say a bit more?",
            )

        summaries = "; ".join(e.summary for e in entries)
        return ExtractionResult(entries=entries, reply=f"Logged: {summaries}")

    @staticmethod
    def _meal_type(lowered: str) -> str:
        for meal in ("breakfast", "lunch", "dinner", "snack"):
            if meal in lowered:
                return meal
        return "snack"

    @staticmethod
    def _activity_type(lowered: str) -> str:
        for word in ACTIVITY_WORDS:
            if word in lowered:
                return word
        return "activity"
