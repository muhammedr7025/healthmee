"""Deterministic, offline-safe sentence builder for the Trends "read"
summary — used as MockProvider's narrate() and as the base-class default,
so the feature is fully exercisable with zero LLM calls (same philosophy
as the mock extractor).
"""

_MOOD_WORDS = [(4.5, "great"), (3.5, "good"), (2.5, "okay"), (1.5, "low"), (0, "rough")]


def _mood_word(score: float) -> str:
    for threshold, word in _MOOD_WORDS:
        if score >= threshold:
            return word
    return "okay"


def default_narrative(stats: dict) -> str:
    days_logged = stats.get("days_logged", 0)
    days_total = stats.get("days_total", 0)
    log_count = stats.get("log_count", 0)

    if days_logged == 0:
        return "Nothing logged in this period yet — once you tell Mo a few things, a summary will show up here."

    sentences = [f"You logged something on {days_logged} of the last {days_total} days ({log_count} entries total)."]

    avg_sleep = stats.get("avg_sleep")
    if avg_sleep is not None:
        sentences.append(f"Sleep averaged {avg_sleep:.1f}h a night.")

    avg_mood = stats.get("avg_mood")
    if avg_mood is not None:
        sentences.append(f"Mood was mostly {_mood_word(avg_mood)} across the days you logged it.")

    total_activity = stats.get("total_activity_minutes")
    if total_activity:
        sentences.append(f"You moved for about {round(total_activity)} minutes in total.")

    return " ".join(sentences)
