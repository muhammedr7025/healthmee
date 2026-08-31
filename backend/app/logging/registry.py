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


def validate_payload(type_name: str, payload: dict) -> list[str]:
    definition = get_type(type_name)
    if definition is None:
        return [f"Unknown log type '{type_name}'"]

    errors = []
    for field_name, spec in definition.schema.items():
        value = payload.get(field_name)
        if value is None:
            if spec.get("required"):
                errors.append(f"'{field_name}' is required for type '{type_name}'")
            continue

        expected = spec["type"]
        if expected not in _SIMPLE_TYPES:
            continue
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
