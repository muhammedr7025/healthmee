"""Allergen matching shared by the extraction handler and the offline
extractor: whole words only (so "nut" no longer fires inside "donut") plus
the everyday synonyms and Indian names a person actually types."""

import re

SYNONYMS: dict[str, list[str]] = {
    "peanut": ["peanuts", "groundnut", "groundnuts", "moongphali", "peanut butter", "peanut chutney"],
    "nut": ["nuts", "almond", "almonds", "cashew", "cashews", "walnut", "walnuts", "pistachio", "pistachios", "badam", "kaju", "peanut", "peanuts"],
    "tree nut": ["almond", "almonds", "cashew", "cashews", "walnut", "walnuts", "pistachio", "pistachios", "badam", "kaju", "hazelnut"],
    "milk": ["dairy", "lactose", "doodh", "paneer", "curd", "dahi", "cheese", "butter", "ghee", "cream", "ice cream", "kheer", "lassi"],
    "dairy": ["milk", "lactose", "doodh", "paneer", "curd", "dahi", "cheese", "butter", "ghee", "cream", "ice cream", "kheer", "lassi"],
    "lactose": ["milk", "dairy", "doodh", "paneer", "curd", "dahi", "cheese", "ice cream", "kheer", "lassi"],
    "egg": ["eggs", "anda", "ande", "omelette", "omelet", "mayonnaise", "mayo"],
    "wheat": ["gluten", "atta", "roti", "chapati", "chapathi", "bread", "maida", "paratha", "naan", "pasta", "noodles"],
    "gluten": ["wheat", "atta", "roti", "chapati", "chapathi", "bread", "maida", "paratha", "naan", "pasta", "noodles"],
    "soy": ["soya", "soybean", "soyabean", "tofu", "soy sauce"],
    "shellfish": ["prawn", "prawns", "shrimp", "shrimps", "crab", "lobster", "jhinga"],
    "fish": ["machli", "machhli", "tuna", "salmon", "sardine", "mackerel"],
    "sesame": ["til", "tahini"],
    "mustard": ["sarson", "rai"],
}


def matching_allergens(allergies: list[str], texts: list[str]) -> list[str]:
    """The user's allergies that appear — by name or synonym, as whole words —
    in any of the texts. Returns the allergy names as the user wrote them."""
    hay = " ".join(t.lower() for t in texts if t)
    if not hay.strip():
        return []
    hits = []
    for allergy in allergies:
        name = allergy.lower().strip()
        if not name:
            continue
        terms = {name, name.rstrip("s"), *SYNONYMS.get(name, []), *SYNONYMS.get(name.rstrip("s"), [])}
        if any(re.search(rf"\b{re.escape(term)}\b", hay) for term in terms if term):
            hits.append(allergy)
    return hits
