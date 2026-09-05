import base64
import json

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class OpenAIProvider(LLMProvider):
    def __init__(self, api_key: str, model: str):
        from openai import OpenAI

        self._client = OpenAI(api_key=api_key)
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

        message = response.choices[0].message
        if message.tool_calls:
            data = json.loads(message.tool_calls[0].function.arguments)
            entries = [
                ExtractedEntry(type=e["type"], payload=e.get("payload", {}), summary=e.get("summary", ""))
                for e in data.get("entries", [])
            ]
            return ExtractionResult(entries=entries, reply=data.get("reply", ""))

        return ExtractionResult(entries=[], reply="Sorry, I couldn't process that message.")

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        try:
            response = self._client.chat.completions.create(
                model=self._model,
                messages=[
                    {
                        "role": "user",
                        "content": _user_content(
                            "This is a photo of a lab report. Extract every test result you can read as a "
                            'JSON array of objects: [{"test_name": str, "value": str, "unit": str or null}]. '
                            "Return ONLY the JSON array, no other text. If you can't read any values, return [].",
                            image_bytes,
                            image_mime_type,
                        ),
                    }
                ],
            )
            text = (response.choices[0].message.content or "").strip()
            data = parse_json_loose(text)
            return [d for d in data if isinstance(d, dict) and d.get("test_name") and d.get("value")]
        except Exception:
            return []

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
            text = (response.choices[0].message.content or "").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            return super().narrate(prompt, stats)


def _user_content(text: str, image_bytes: bytes | None, image_mime_type: str | None):
    if image_bytes is None:
        return text
    b64 = base64.b64encode(image_bytes).decode()
    return [
        {"type": "text", "text": text},
        {"type": "image_url", "image_url": {"url": f"data:{image_mime_type or 'image/jpeg'};base64,{b64}"}},
    ]
