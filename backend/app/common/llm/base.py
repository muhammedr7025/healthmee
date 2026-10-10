from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


@dataclass
class ExtractedEntry:
    type: str
    payload: dict
    summary: str
    # ISO 8601 *local* wall-clock time the thing happened, when the message
    # said so ("yesterday", "for dinner", "at 7pm"); None means "now".
    occurred_at: str | None = None


@dataclass
class ExtractionResult:
    entries: list[ExtractedEntry]
    reply: str


class LLMProvider(ABC):
    """Structured-extraction interface. Every provider turns a free-text log
    message into zero or more typed entries plus a conversational reply,
    using the registered log-type catalog to know what fields to look for.
    """

    @abstractmethod
    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
        local_now: datetime | None = None,
    ) -> ExtractionResult:
        """`image_bytes`/`image_mime_type` are set when the message included
        a photo (VitaChat's photo logging). Providers without vision
        support can ignore them — MockProvider does, honestly, rather than
        fabricating what's in a photo it can't see.

        `local_now` is the user's current wall-clock time, so "yesterday"
        and "for dinner" can be resolved to an `occurred_at`.
        """
        raise NotImplementedError

    def read_lab_report(self, file_bytes: bytes, mime_type: str) -> dict:
        """Lab-report reading from a photo or a PDF. Returns
        {"report_date": "YYYY-MM-DD" | None, "results": [{test_name, value,
        unit, reference_range}, ...]}. Default: no capability — mock/text-only
        providers return nothing rather than inventing lab values.
        """
        from app.common.llm.lab_report import EMPTY_REPORT

        return dict(EMPTY_REPORT)

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        """Older callers: just the rows of `read_lab_report`."""
        return self.read_lab_report(image_bytes, image_mime_type)["results"]

    def narrate(self, prompt: str, stats: dict) -> str:
        """Trends "read" summary (VitaChat's period narrative). Default is a
        deterministic, no-network sentence built straight from `stats` — the
        same offline-safe fallback MockProvider gets for free. Real providers
        override this to turn `prompt` into flowing prose via their API.
        """
        from app.common.llm.narrative_fallback import default_narrative

        return default_narrative(stats)
