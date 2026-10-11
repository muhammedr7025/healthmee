import base64

from flask import current_app

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.lab_report import EMPTY_REPORT, LAB_REPORT_PROMPT, normalise_lab_report
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class AnthropicProvider(LLMProvider):
    name = "anthropic"

    def __init__(self, api_key: str, model: str, timeout: float = 20.0):
        import anthropic

        # Fail fast: the SDK default is 600s with 2 retries, which would hold
        # a worker long past gunicorn's timeout and skip the offline fallback.
        self._client = anthropic.Anthropic(api_key=api_key, timeout=timeout, max_retries=1)
        self._model = model
        self.model_name = model

    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
        local_now=None,
        user_context=None,
    ) -> ExtractionResult:
        tool = build_tool_schema(type_catalog)
        system = build_system_prompt(type_catalog, local_now=local_now, user_context=user_context)
        content = _user_content(text or "What's in this photo? Log it.", image_bytes, image_mime_type)

        response = self._client.messages.create(
            model=self._model,
            max_tokens=1024,
            system=system,
            tools=[tool],
            tool_choice={"type": "tool", "name": "log_entries"},
            messages=[{"role": "user", "content": content}],
        )

        usage = _usage(response)
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
                    if isinstance(e, dict) and e.get("type")
                ]
                return ExtractionResult(
                    entries=entries, reply=data.get("reply", ""), usage=usage, question=(data.get("clarifying_question") or None)
                )

        return ExtractionResult(entries=[], reply="Sorry, I couldn't process that message.", usage=usage)

    def read_lab_report(self, file_bytes: bytes, mime_type: str) -> dict:
        try:
            content = _user_content(LAB_REPORT_PROMPT, file_bytes, mime_type)
            response = self._client.messages.create(
                model=self._model, max_tokens=4096, messages=[{"role": "user", "content": content}]
            )
            self.last_usage = _usage(response)
            if getattr(response, "stop_reason", None) == "max_tokens":
                current_app.logger.warning("lab report read truncated at max_tokens")
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            return normalise_lab_report(parse_json_loose(text))
        except Exception:
            current_app.logger.exception("anthropic lab report read failed")
            return dict(EMPTY_REPORT)

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            response = self._client.messages.create(
                model=self._model,
                max_tokens=400,
                system="You are MeMe, a warm, non-clinical health journal companion. Write 2-4 short "
                "sentences, plain prose, no markdown, no diagnosis language.",
                messages=[{"role": "user", "content": prompt}],
            )
            self.last_usage = _usage(response)
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            current_app.logger.exception("anthropic narrate failed; using the deterministic summary")
            return super().narrate(prompt, stats)


def _usage(response) -> dict | None:
    usage = getattr(response, "usage", None)
    if usage is None:
        return None
    return {"input_tokens": getattr(usage, "input_tokens", None), "output_tokens": getattr(usage, "output_tokens", None)}


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
