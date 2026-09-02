from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class ExtractedEntry:
    type: str
    payload: dict
    summary: str


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
    ) -> ExtractionResult:
        """`image_bytes`/`image_mime_type` are set when the message included
        a photo (VitaChat's photo logging). Providers without vision
        support can ignore them — MockProvider does, honestly, rather than
        fabricating what's in a photo it can't see.
        """
        raise NotImplementedError

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        """OCR lab-report scanning. Default: no capability — mock/text-only
        providers return nothing rather than inventing lab values. Vision
        providers override this to return [{test_name, value, unit}, ...].
        """
        return []

    def narrate(self, prompt: str, stats: dict) -> str:
        """Trends "read" summary (VitaChat's period narrative). Default is a
        deterministic, no-network sentence built straight from `stats` — the
        same offline-safe fallback MockProvider gets for free. Real providers
        override this to turn `prompt` into flowing prose via their API.
        """
        from app.common.llm.narrative_fallback import default_narrative

        return default_narrative(stats)
