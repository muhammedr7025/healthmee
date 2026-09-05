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
- summary must be a short human-readable one-liner, e.g. "oatmeal + banana, ~320 kcal".
"""


def build_system_prompt(type_catalog: list[dict]) -> str:
    lines = []
    for t in type_catalog:
        fields = ", ".join(_describe_field(name, spec) for name, spec in t["schema"].items())
        lines.append(f"- {t['name']}: {t['description']} (fields — {fields})")
    return SYSTEM_PROMPT_TEMPLATE.format(type_descriptions="\n".join(lines))


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
