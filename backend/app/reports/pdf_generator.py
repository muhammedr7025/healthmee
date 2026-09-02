"""Builds the "doctor report" PDF from real data — no placeholder content.
Sections mirror the VitaChat Reports screen's "what goes in" checklist:
logs, trends, lab history. Symptom photos are never included since photo
logging isn't implemented yet.
"""

import io
from datetime import date

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

_INK = colors.HexColor("#241F1A")
_MUTED = colors.HexColor("#8A7F70")
_ACCENT = colors.HexColor("#B4633F")
_RULE = colors.HexColor("#E7DDCD")


def build_report_pdf(
    *,
    user_name: str,
    user_email: str,
    start: date,
    end: date,
    conditions: list[str],
    allergies: list[dict],
    medications: list[str],
    baseline_vitals: dict,
    lab_results: list[dict],
    log_entries: list[dict],
    daily_aggregates: list[dict],
) -> tuple[bytes, int]:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        topMargin=0.85 * inch,
        bottomMargin=0.75 * inch,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("VCTitle", parent=styles["Title"], textColor=_INK, fontSize=26, spaceAfter=4)
    h2 = ParagraphStyle("VCH2", parent=styles["Heading2"], textColor=_INK, spaceBefore=18, spaceAfter=8)
    body = ParagraphStyle("VCBody", parent=styles["BodyText"], textColor=_INK, fontSize=10.5, leading=15)
    muted = ParagraphStyle("VCMuted", parent=styles["BodyText"], textColor=_MUTED, fontSize=9.5)

    story = []

    # Cover
    story.append(Paragraph("VitaChat health summary", title_style))
    story.append(Paragraph(f"{user_name or user_email}", body))
    story.append(Paragraph(f"{start.isoformat()} to {end.isoformat()}", muted))
    story.append(Paragraph(
        "This is a summary of self-reported data from the VitaChat journal. It is not a diagnosis "
        "and does not replace clinical judgment.",
        muted,
    ))
    story.append(Spacer(1, 0.15 * inch))

    # Medical profile
    story.append(Paragraph("Medical profile", h2))
    story.append(Paragraph(f"<b>Conditions:</b> {', '.join(conditions) or 'None recorded'}", body))
    hard_allergies = ", ".join(a["name"] for a in allergies) or "None recorded"
    story.append(Paragraph(f"<b>Allergies (hard flags):</b> {hard_allergies}", body))
    story.append(Paragraph(f"<b>Medications:</b> {', '.join(medications) or 'None recorded'}", body))
    if baseline_vitals:
        vitals_line = ", ".join(f"{k}: {v}" for k, v in baseline_vitals.items())
        story.append(Paragraph(f"<b>Baseline vitals:</b> {vitals_line}", body))

    # Lab history
    story.append(Paragraph("Lab history", h2))
    if lab_results:
        rows = [["Test", "Value", "Source", "Date"]]
        for lab in lab_results:
            rows.append([lab["test_name"], f"{lab['value']} {lab.get('unit') or ''}".strip(), lab["source"], lab["taken_at"][:10]])
        story.append(_table(rows))
    else:
        story.append(Paragraph("No lab results recorded in this period.", muted))

    # Trends
    story.append(Paragraph("Trends", h2))
    if daily_aggregates:
        sleep_vals = [d["sleep_hours"] for d in daily_aggregates if d.get("sleep_hours") is not None]
        mood_vals = [d["mood_score"] for d in daily_aggregates if d.get("mood_score") is not None]
        avg_sleep = f"{sum(sleep_vals) / len(sleep_vals):.1f}h" if sleep_vals else "—"
        avg_mood = f"{sum(mood_vals) / len(mood_vals):.1f}/5" if mood_vals else "—"
        total_activity = sum(d["activity_minutes"] for d in daily_aggregates)
        days_logged = sum(1 for d in daily_aggregates if d["log_count"] > 0)
        story.append(Paragraph(
            f"Logged on {days_logged} of {len(daily_aggregates)} days. "
            f"Average sleep {avg_sleep}. Average mood {avg_mood}. "
            f"Total activity {round(total_activity)} minutes.",
            body,
        ))
    else:
        story.append(Paragraph("No trend data recorded in this period.", muted))

    # Logbook
    story.append(PageBreak())
    story.append(Paragraph(f"Logbook · {len(log_entries)} entries", h2))
    if log_entries:
        rows = [["Date", "Type", "Summary"]]
        for entry in log_entries[:200]:  # cap so a heavy user's PDF doesn't balloon
            rows.append([entry["timestamp"][:10], entry["type"], (entry.get("summary") or "")[:70]])
        story.append(_table(rows))
        if len(log_entries) > 200:
            story.append(Paragraph(f"...and {len(log_entries) - 200} more entries not shown.", muted))
    else:
        story.append(Paragraph("No log entries in this period.", muted))

    doc.build(story)
    return buffer.getvalue(), doc.page


def _table(rows: list[list[str]]) -> Table:
    table = Table(rows, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("BACKGROUND", (0, 0), (-1, 0), _ACCENT),
        ("GRID", (0, 0), (-1, -1), 0.5, _RULE),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#FFFDF8")]),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    return table
