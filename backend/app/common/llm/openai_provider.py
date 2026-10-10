import base64

from flask import current_app

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.lab_report import EMPTY_REPORT, LAB_REPORT_PROMPT, normalise_lab_report
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class OpenAIProvider(LLMProvider):
    name = "openai"

    def __init__(self, api_key: str, model: str, timeout: float = 20.0):
        from openai import OpenAI

        self._client = OpenAI(api_key=api_key, timeout=timeout, max_retries=1)
        self._model = model
        self.model_name = model

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

        function_schema = {
            "type": "function",
            "function": {
                "name": tool["name"],
                "description": tool["description"],
                "parameters": tool["input_schema"],
            },
        }

        response = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": _user_content(text or "What's in this photo? Log it.", image_bytes, image_mime_type)},
            ],
            tools=[function_schema],
            tool_choice={"type": "function", "function": {"name": "log_entries"}},
        )

        usage = _usage(response)
        message = response.choices[0].message
        if message.tool_calls:
            data = parse_json_loose(message.tool_calls[0].function.arguments)
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
            return ExtractionResult(entries=entries, reply=data.get("reply", ""), usage=usage)

        return ExtractionResult(entries=[], reply="Sorry, I couldn't process that message.", usage=usage)

    def read_lab_report(self, file_bytes: bytes, mime_type: str) -> dict:
        try:
            response = self._client.chat.completions.create(
                model=self._model,
                messages=[{"role": "user", "content": _user_content(LAB_REPORT_PROMPT, file_bytes, mime_type)}],
                response_format={"type": "json_object"},
                max_tokens=4096,
            )
            self.last_usage = _usage(response)
            text = (response.choices[0].message.content or "").strip()
            return normalise_lab_report(parse_json_loose(text))
        except Exception:
            current_app.logger.exception("openai lab report read failed")
            return dict(EMPTY_REPORT)

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            response = self._client.chat.completions.create(
                model=self._model,
                messages=[
                    {
                        "role": "system",
                        "content": "You are MeMe, a warm, non-clinical health journal companion. Write 2-4 "
                        "short sentences, plain prose, no markdown, no diagnosis language.",
                    },
                    {"role": "user", "content": prompt},
                ],
                max_tokens=400,
            )
            self.last_usage = _usage(response)
            text = (response.choices[0].message.content or "").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            current_app.logger.exception("openai narrate failed; using the deterministic summary")
            return super().narrate(prompt, stats)


def _usage(response) -> dict | None:
    usage = getattr(response, "usage", None)
    if usage is None:
        return None
    return {"input_tokens": getattr(usage, "prompt_tokens", None), "output_tokens": getattr(usage, "completion_tokens", None)}


def _user_content(text: str, file_bytes: bytes | None, mime_type: str | None):
    if file_bytes is None:
        return text
    mime_type = mime_type or "image/jpeg"
    b64 = base64.b64encode(file_bytes).decode()
    if mime_type == "application/pdf":
        attachment = {"type": "file", "file": {"filename": "report.pdf", "file_data": f"data:{mime_type};base64,{b64}"}}
    else:
        attachment = {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{b64}"}}
    return [{"type": "text", "text": text}, attachment]
