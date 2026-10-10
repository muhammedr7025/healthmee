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


def build_system_prompt(type_catalog: list[dict], local_now=None) -> str:
    lines = []
    for t in type_catalog:
        fields = ", ".join(_describe_field(name, spec) for name, spec in t["schema"].items())
        lines.append(f"- {t['name']}: {t['description']} (fields — {fields})")
    prompt = SYSTEM_PROMPT_TEMPLATE.format(type_descriptions="\n".join(lines))
    if local_now is not None:
        prompt += TIME_RULES_TEMPLATE.format(local_now=local_now.strftime("%A %Y-%m-%d %H:%M"))
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
            },
            "required": ["entries", "reply"],
        },
    }
