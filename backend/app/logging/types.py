from app.logging.extraction.handlers import allergy_check_handler, symptom_disclaimer_handler
from app.logging.registry import LogTypeDefinition, register_type


def register_builtin_types() -> None:
    register_type(
        LogTypeDefinition(
            name="food",
            description="Something the user ate or drank",
            schema={
                "food_items": {"type": "list[str]", "required": True},
                "meal_type": {
                    "type": "str",
                    "required": False,
                    "enum": ["breakfast", "lunch", "dinner", "snack"],
                },
                "estimated_calories": {"type": "number", "required": False},
                "protein_g": {"type": "number", "required": False},
                "carbs_g": {"type": "number", "required": False},
                "fat_g": {"type": "number", "required": False},
                # Likely allergens in the dish (peanut, milk, egg, wheat, soy, shellfish, fish, tree nut, sesame).
                "allergens": {"type": "list[str]", "required": False},
            },
            handlers=[allergy_check_handler],
        )
    )

    register_type(
        LogTypeDefinition(
            name="sleep",
            description="A night's sleep duration/quality",
            schema={
                "hours": {"type": "number", "required": True},
                "quality": {"type": "str", "required": False, "enum": ["poor", "fair", "good"]},
            },
        )
    )

    register_type(
        LogTypeDefinition(
            name="hydration",
            description="Water or another drink the user consumed, for fluid tracking",
            schema={
                "volume_ml": {"type": "number", "required": True},
                "beverage": {"type": "str", "required": False},
            },
        )
    )

    register_type(
        LogTypeDefinition(
            name="mood",
            description="How the user is feeling emotionally",
            schema={
                "mood": {
                    "type": "str",
                    "required": True,
                    "enum": ["happy", "sad", "stressed", "calm", "tired"],
                },
                "intensity": {"type": "number", "required": False},
            },
        )
    )

    register_type(
        LogTypeDefinition(
            name="activity",
            description="Physical activity or exercise",
            schema={
                "activity_type": {"type": "str", "required": True},
                "duration_minutes": {"type": "number", "required": False},
                "estimated_calories_burned": {"type": "number", "required": False},
            },
        )
    )

    register_type(
        LogTypeDefinition(
            name="stress",
            description="A stress event or stress level check-in",
            schema={
                "level": {"type": "number", "required": True},
                "trigger": {"type": "str", "required": False},
            },
        )
    )

    register_type(
        LogTypeDefinition(
            name="symptom",
            description="A physical symptom the user is experiencing (never diagnosed, only logged)",
            schema={
                "description": {"type": "str", "required": True},
                "body_area": {"type": "str", "required": False},
            },
            handlers=[symptom_disclaimer_handler],
        )
    )

    register_type(
        LogTypeDefinition(
            name="vital",
            description=(
                "A measured vital sign the user reports: blood pressure, blood glucose/sugar, "
                "weight, heart rate/pulse, body temperature or SpO2. `value` is the reading "
                "(the systolic number for blood pressure, with `diastolic` separate); `unit` as "
                "spoken (mmHg, mg/dL, mmol/L, kg, lb, bpm, °C, °F, %)"
            ),
            schema={
                "kind": {
                    "type": "str",
                    "required": True,
                    "enum": ["blood_pressure", "blood_glucose", "weight", "heart_rate", "temperature", "spo2"],
                },
                "value": {"type": "number", "required": True},
                "diastolic": {"type": "number", "required": False},
                "unit": {"type": "str", "required": False},
                "context": {
                    "type": "str",
                    "required": False,
                    "enum": ["fasting", "post_meal", "resting", "after_exercise", "morning", "bedtime"],
                },
            },
        )
    )
