import base64
import json

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
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
    ) -> ExtractionResult:
        tool = build_tool_schema(type_catalog)
        system = build_system_prompt(type_catalog)
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
                    ExtractedEntry(type=e["type"], payload=e.get("payload", {}), summary=e.get("summary", ""))
                    for e in data.get("entries", [])
                ]
                return ExtractionResult(entries=entries, reply=data.get("reply", ""))

        return ExtractionResult(entries=[], reply="Sorry, I couldn't process that message.")

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        try:
            content = _user_content(
                "This is a photo of a lab report. Extract every test result you can read as a JSON array "
                'of objects: [{"test_name": str, "value": str, "unit": str or null}]. '
                "Return ONLY the JSON array, no other text. If you can't read any values, return [].",
                image_bytes,
                image_mime_type,
            )
            response = self._client.messages.create(
                model=self._model, max_tokens=1024, messages=[{"role": "user", "content": content}]
            )
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            data = json.loads(text)
            return [d for d in data if isinstance(d, dict) and d.get("test_name") and d.get("value")]
        except Exception:
            return []

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            response = self._client.messages.create(
                model=self._model,
                max_tokens=400,
                system="You are Mo, a warm, non-clinical health journal companion. Write 2-4 short "
                "sentences, plain prose, no markdown, no diagnosis language, first person plural avoided.",
                messages=[{"role": "user", "content": prompt}],
            )
            text = "".join(b.text for b in response.content if b.type == "text").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            return super().narrate(prompt, stats)


def _user_content(text: str, image_bytes: bytes | None, image_mime_type: str | None):
    if image_bytes is None:
        return text
    return [
        {
            "type": "image",
            "source": {"type": "base64", "media_type": image_mime_type or "image/jpeg", "data": base64.b64encode(image_bytes).decode()},
        },
        {"type": "text", "text": text},
    ]
