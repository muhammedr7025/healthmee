"""The LogEntry type catalog. Adding a new log type (e.g. "hydration") means
adding one entry here — a name, a field schema, and optional handlers — never
touching LogEntry itself, the extraction pipeline, or existing types
(dev-prompt §6/§7).
"""

from dataclasses import dataclass, field
from typing import Callable

_SIMPLE_TYPES = {"str", "number", "bool", "list[str]", "list[number]", "dict"}


@dataclass
class LogTypeDefinition:
    name: str
    description: str
    schema: dict[str, dict]  # field_name -> {"type": ..., "required": bool, "enum": [...]?}
    handlers: list[Callable] = field(default_factory=list)


_REGISTRY: dict[str, LogTypeDefinition] = {}


def register_type(definition: LogTypeDefinition) -> None:
    _REGISTRY[definition.name] = definition


def get_type(name: str) -> LogTypeDefinition | None:
    return _REGISTRY.get(name)


def get_type_names() -> list[str]:
    return list(_REGISTRY.keys())


def get_type_catalog() -> list[dict]:
    """Serialized form handed to the LLM prompt builder."""
    return [
        {"name": t.name, "description": t.description, "schema": t.schema}
        for t in _REGISTRY.values()
    ]


def _field_errors(field_name: str, spec: dict, value) -> list[str]:
    """Type/enum checks for one field's value. Shared by validate_payload
    (whole-payload, used before insert) and sanitize_payload (per-field, used
    to salvage an entry around one bad optional field) so the two can't drift
    out of sync with each other.
    """
    if value is None:
        return [f"'{field_name}' is required"] if spec.get("required") else []

    errors = []
    expected = spec["type"]
    if expected in _SIMPLE_TYPES:
        if expected == "str" and not isinstance(value, str):
            errors.append(f"'{field_name}' must be a string")
        elif expected == "number" and not isinstance(value, (int, float)):
            errors.append(f"'{field_name}' must be a number")
        elif expected == "bool" and not isinstance(value, bool):
            errors.append(f"'{field_name}' must be a boolean")
        elif expected == "list[str]" and not (
            isinstance(value, list) and all(isinstance(v, str) for v in value)
        ):
            errors.append(f"'{field_name}' must be a list of strings")
        elif expected == "list[number]" and not (
            isinstance(value, list) and all(isinstance(v, (int, float)) for v in value)
        ):
            errors.append(f"'{field_name}' must be a list of numbers")
        elif expected == "dict" and not isinstance(value, dict):
            errors.append(f"'{field_name}' must be an object")

    enum = spec.get("enum")
    if enum and value not in enum:
        errors.append(f"'{field_name}' must be one of {enum}")

    return errors


def validate_payload(type_name: str, payload: dict) -> list[str]:
    definition = get_type(type_name)
    if definition is None:
        return [f"Unknown log type '{type_name}'"]

    errors = []
    for field_name, spec in definition.schema.items():
        errors.extend(_field_errors(field_name, spec, payload.get(field_name)))
    return errors


def sanitize_payload(type_name: str, payload: dict) -> tuple[dict, list[str]]:
    """Drops optional fields the model got wrong, keeping the entry itself.

    A model will happily answer "very poor" for sleep quality or "anxious"
    for mood — values that read as reasonable but don't match our enum.
    Rejecting the whole entry for that used to throw away the part that
    actually mattered (the 5 hours of sleep), and the log vanished with no
    sign it had happened. Required fields still fail loudly via
    validate_payload — an entry missing one is meaningless either way.
    """
    definition = get_type(type_name)
    if definition is None:
        return payload, [f"Unknown log type '{type_name}'"]

    cleaned = dict(payload)
    dropped = []
    for field_name, spec in definition.schema.items():
        if spec.get("required") or field_name not in cleaned:
            continue
        errors = _field_errors(field_name, spec, cleaned[field_name])
        if errors:
            dropped.append(f"dropped invalid optional '{field_name}' ({errors[0]})")
            del cleaned[field_name]

    return cleaned, dropped
