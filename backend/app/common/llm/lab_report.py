"""Lab-report reading shared by the vision providers: one prompt, one
normaliser, so a photo of a printout and a hospital-portal PDF come back in
the same shape and the route doesn't care which provider read it.
"""

from datetime import date, timedelta

EMPTY_REPORT = {"report_date": None, "results": []}

LAB_REPORT_PROMPT = (
    "This is a lab report — a photo of a printout or a PDF. Read every measured test result on it.\n"
    "Return JSON only, in exactly this shape:\n"
    '{"report_date": "YYYY-MM-DD or null", "results": [{"test_name": str, "value": str, '
    '"unit": str or null, "reference_range": str or null}]}\n'
    "- report_date is the sample collection date if printed, otherwise the report date, otherwise null. "
    "Never use today's date.\n"
    "- value exactly as printed, decimals kept, no unit inside it. reference_range as printed, "
    'e.g. "70-100" or "<200".\n'
    "- Skip headers, patient details, doctor names and anything that isn't a measured result.\n"
    '- If you can\'t read any values, return {"report_date": null, "results": []}.'
)


def normalise_lab_report(data) -> dict:
    """Coerces whatever JSON a model returned into {report_date, results}.
    Tolerates the bare array older prompts produced and arrays hidden under
    an unexpected key; drops rows with no test name or value; clips strings
    to the column widths they're about to be stored in."""
    if isinstance(data, list):
        data = {"results": data}
    if not isinstance(data, dict):
        return dict(EMPTY_REPORT)

    rows = data.get("results")
    if not isinstance(rows, list):
        rows = next((v for v in data.values() if isinstance(v, list)), [])

    results = []
    for item in rows:
        if not isinstance(item, dict) or not item.get("test_name") or item.get("value") in (None, ""):
            continue
        results.append(
            {
                "test_name": str(item["test_name"]).strip()[:255],
                "value": str(item["value"]).strip()[:64],
                "unit": _clean(item.get("unit"), 32),
                "reference_range": _clean(item.get("reference_range"), 64),
            }
        )
    return {"report_date": _valid_date(data.get("report_date")), "results": results}


def _clean(value, width: int) -> str | None:
    if value is None:
        return None
    text = str(value).strip()[:width]
    return text or None


def _valid_date(raw) -> str | None:
    """An ISO date that is plausibly a report date — not in the future, not
    a hallucinated 1900 — else None so the app falls back to asking."""
    if not raw:
        return None
    try:
        parsed = date.fromisoformat(str(raw).strip()[:10])
    except ValueError:
        return None
    if parsed > date.today() + timedelta(days=1) or parsed.year < 1990:
        return None
    return parsed.isoformat()
