SYSTEM_PROMPT_TEMPLATE = """You are the extraction engine behind MeMe, a warm and encouraging health-journal \
mascot. A user just sent a free-text health log message, possibly with a photo attached. Identify every \
distinct loggable thing in the message and/or photo (it may contain more than one — e.g. food AND mood) \
and return it as structured entries, plus a short, warm, conversational reply \
confirming what you logged (never clinical, never guilt-tripping).

Only use these entry types, each with its expected payload fields:

{type_descriptions}

Rules:
- If the message doesn't describe anything loggable, return an empty entries list \
and a friendly reply asking for more detail.
- Never invent precise medical values you can't infer from the text; omit optional \
fields you're unsure about rather than guessing wildly.
- For food, give a rough estimated_calories and, when the dish is recognisable, \
protein_g / carbs_g / fat_g for the whole entry (typical portions; it's a journal, \
not a lab). Mark estimates with "~" in the summary.
- summary must be a short human-readable one-liner, e.g. "oatmeal + banana, ~320 kcal".
"""

TIME_RULES_TEMPLATE = """
When it happened:
- The user's current local date and time is {local_now} (their own timezone — \
use it as "now"; never convert to UTC).
- If the message says when something happened — "yesterday", "this morning", \
"for dinner", "at 7pm", "two days ago" — set that entry's occurred_at to the local \
date-time as ISO 8601 with no timezone suffix, e.g. 2026-10-10T20:00.
- A meal named without a time: breakfast 08:00, lunch 13:00, dinner 20:00. \
"Yesterday" with no time: the same clock time as now, one day earlier.
- A clock time later than now means the most recent one that already happened: \
"at 4pm" typed at 01:00 is yesterday 16:00. Nothing is ever logged in the future.
- A night's sleep belongs to the morning the user woke up: "slept 7h last night" \
is today — omit occurred_at.
- If nothing in the message says when, omit occurred_at entirely (it means now).
"""


USER_CONTEXT_TEMPLATE = """
About this person (use it; never recite it back to them):
- Name: {name}
- Allergies — ALWAYS check every food against these: {allergies}
- Conditions: {conditions}. Medications: {medications}.
- Goals: {goals}
- Units: metric — kg, cm, mmHg, mg/dL (blood sugar may also arrive in mmol/L). They live in {locale} and \
may write in Hinglish ("2 roti khaya", "paani piya", "raat ko 7 ghante soya"); understand it, reply in plain English.
- Today so far ({date}): {kcal} kcal, {water_l} L water, {activity_min} min active, last sleep {sleep_h}, {log_count} logs.
- Recent logs: {recent}
Indian portions when estimating: roti/chapati ~70 kcal, idli ~40, plain dosa ~130, 1 cup cooked rice ~200, \
1 cup dal ~180, 1 cup sambar ~130, chai with milk and sugar ~90, paratha ~150, 1 plate biryani ~500, \
1 cup curd ~100, 100 g paneer ~265, 1 banana ~90.

Reply rules:
- If a food contains or likely contains one of their allergens, say so FIRST and plainly ("Heads up — that has \
peanuts, which is on your allergy list") and put it in that entry's allergens field. Never bury it after a cheerful line.
- One sentence that acknowledges what they said, one that adds something from their own day or goals (a running \
total, a nudge toward a target). No lectures, no strings of emoji, vary your openers.
- Ask at most ONE short question in clarifying_question, only when something essential is missing — the second \
blood-pressure number, a portion that changes the picture. Still log what you can.

Good replies:
- "Logged the idli and sambar — a light ~250 kcal start. You're at 0.5 L of water so far; a glass with lunch would be a good move."
- "Heads up — peanut chutney has peanuts, which is on your allergy list. I've logged it; please double-check before eating."
- "BP 128/82 noted, right in the usual range. That's your third reading this week — nice consistency."
"""


def _fmt_list(items, empty: str = "none recorded") -> str:
    items = [str(i) for i in (items or []) if str(i).strip()]
    return ", ".join(items) if items else empty


def build_system_prompt(type_catalog: list[dict], local_now=None, user_context: dict | None = None) -> str:
    lines = []
    for t in type_catalog:
        fields = ", ".join(_describe_field(name, spec) for name, spec in t["schema"].items())
        lines.append(f"- {t['name']}: {t['description']} (fields — {fields})")
    prompt = SYSTEM_PROMPT_TEMPLATE.format(type_descriptions="\n".join(lines))
    if local_now is not None:
        prompt += TIME_RULES_TEMPLATE.format(local_now=local_now.strftime("%A %Y-%m-%d %H:%M"))
    if user_context:
        today = user_context.get("today") or {}
        sleep = today.get("sleep_h")
        prompt += USER_CONTEXT_TEMPLATE.format(
            name=user_context.get("name") or "not given",
            allergies=_fmt_list(user_context.get("allergies"), "none recorded — still mention common allergens if a dish obviously contains them"),
            conditions=_fmt_list(user_context.get("conditions")),
            medications=_fmt_list(user_context.get("medications")),
            goals=_fmt_list(user_context.get("goals"), "none set"),
            locale=user_context.get("locale") or "their own country",
            date=today.get("date", ""),
            kcal=today.get("kcal", 0),
            water_l=today.get("water_l", 0),
            activity_min=today.get("activity_min", 0),
            sleep_h=f"{sleep:g}h" if isinstance(sleep, (int, float)) else "not logged",
            log_count=today.get("log_count", 0),
            recent=_fmt_list(user_context.get("recent"), "nothing yet"),
        )
    return prompt


def _describe_field(name: str, spec: dict) -> str:
    """Spells out allowed values for enum fields. Without them the model
    returns sensible-but-invalid labels ("very poor" for sleep quality,
    "anxious" for mood), validation rejects the entry, and the user's log is
    silently dropped.
    """
    described = f"{name}{'*' if spec.get('required') else ''}: {spec['type']}"
    if spec.get("enum"):
        described += " — must be exactly one of: " + ", ".join(spec["enum"])
    return described


def build_tool_schema(type_catalog: list[dict]) -> dict:
    type_names = [t["name"] for t in type_catalog]
    return {
        "name": "log_entries",
        "description": "Record the structured health log entries extracted from the user's message.",
        "input_schema": {
            "type": "object",
            "properties": {
                "entries": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string", "enum": type_names},
                            "payload": {
                                "type": "object",
                                "description": "Fields depend on type — see the per-type field list in the system prompt.",
                            },
                            "summary": {"type": "string"},
                            "occurred_at": {
                                "type": "string",
                                "description": "Local ISO 8601 date-time (no timezone) the entry happened, "
                                "only when the message says when. Omit for 'now'.",
                            },
                        },
                        "required": ["type", "payload", "summary"],
                    },
                },
                "reply": {
                    "type": "string",
                    "description": "A short, warm conversational reply confirming what was logged.",
                },
                "clarifying_question": {
                    "type": "string",
                    "description": "At most one short question, only when something essential is missing "
                    "(e.g. the second blood-pressure number). Omit otherwise.",
                },
            },
            "required": ["entries", "reply"],
        },
    }
