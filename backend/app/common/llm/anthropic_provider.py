import base64
import json

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.lab_report import EMPTY_REPORT, LAB_REPORT_PROMPT, normalise_lab_report
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class AnthropicProvider(LLMProvider):
    def __init__(self, api_key: str, model: str):
        import anthropic

        self._client = anthropic.Anthropic(api_key=api_key)
        self._model = model

    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
        local_now=None,
    ) -> ExtractionResult:
        tool = build_tool_schema(type_catalog)
        system = build_system_prompt(type_catalog, local_now=local_now)
        content = _user_content(text or "What's in this photo? Log it.", image_bytes, image_mime_type)

        response = self._client.messages.create(
            model=self._model,
            max_tokens=1024,
            system=system,
            tools=[tool],
            tool_choice={"type": "tool", "name": "log_entries"},
            messages=[{"role": "user", "content": content}],
        )

        for block in response.content:
            if block.type == "tool_use" and block.name == "log_entries":
                data = block.input
                entries = [
                    ExtractedEntry(
                        type=e["type"],
                        payload=e.get("payload", {}),
                        summary=e.get("summary", ""),
                        occurred_at=e.get("occurred_at"),
                    )
                    for e in data.get("entries", [])
                ]
                return ExtractionResult(entries=entries, reply=data.get("reply", ""))

        return ExtractionResult(entries=[], reply="Sorry, I couldn't process that message.")

    def read_lab_report(self, file_bytes: bytes, mime_type: str) -> dict:
        try:
            content = _user_content(LAB_REPORT_PROMPT, file_bytes, mime_type)
            response = self._client.messages.create(
                model=self._model, max_tokens=2048, messages=[{"role": "user", "content": content}]
            )
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            return normalise_lab_report(parse_json_loose(text))
        except Exception:
            return dict(EMPTY_REPORT)

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            response = self._client.messages.create(
                model=self._model,
                max_tokens=400,
                system="You are MeMe, a warm, non-clinical health journal companion. Write 2-4 short "
                "sentences, plain prose, no markdown, no diagnosis language, first person plural avoided.",
                messages=[{"role": "user", "content": prompt}],
            )
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            return super().narrate(prompt, stats)


def _user_content(text: str, file_bytes: bytes | None, mime_type: str | None):
    if file_bytes is None:
        return text
    mime_type = mime_type or "image/jpeg"
    # PDFs go in as a document block; everything else is an image.
    block_type = "document" if mime_type == "application/pdf" else "image"
    return [
        {
            "type": block_type,
            "source": {"type": "base64", "media_type": mime_type, "data": base64.b64encode(file_bytes).decode()},
        },
        {"type": "text", "text": text},
    ]
