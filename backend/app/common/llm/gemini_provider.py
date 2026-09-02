import json

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class GeminiProvider(LLMProvider):
    """Uses Gemini's JSON-mode structured output (response_schema) rather than
    function calling — simpler and equally reliable for pure extraction.
    """

    def __init__(self, api_key: str, model: str):
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        self._genai = genai
        self._model_name = model

    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
    ) -> ExtractionResult:
        tool = build_tool_schema(type_catalog)
        system = build_system_prompt(type_catalog)

        model = self._genai.GenerativeModel(
            self._model_name,
            system_instruction=system,
            generation_config={
                "response_mime_type": "application/json",
                "response_schema": tool["input_schema"],
            },
        )

        content = _content(text or "What's in this photo? Log it.", image_bytes, image_mime_type)
        response = model.generate_content(content)
        data = json.loads(response.text)
        entries = [
            ExtractedEntry(type=e["type"], payload=e.get("payload", {}), summary=e.get("summary", ""))
            for e in data.get("entries", [])
        ]
        return ExtractionResult(entries=entries, reply=data.get("reply", ""))

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        try:
            model = self._genai.GenerativeModel(self._model_name)
            content = _content(
                "This is a photo of a lab report. Extract every test result you can read as a JSON array "
                'of objects: [{"test_name": str, "value": str, "unit": str or null}]. '
                "Return ONLY the JSON array, no other text. If you can't read any values, return [].",
                image_bytes,
                image_mime_type,
            )
            response = model.generate_content(content)
            data = json.loads(response.text)
            return [d for d in data if isinstance(d, dict) and d.get("test_name") and d.get("value")]
        except Exception:
            return []

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            model = self._genai.GenerativeModel(
                self._model_name,
                system_instruction="You are Mo, a warm, non-clinical health journal companion. Write 2-4 "
                "short sentences, plain prose, no markdown, no diagnosis language.",
            )
            response = model.generate_content(prompt)
            text = (response.text or "").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            return super().narrate(prompt, stats)


def _content(text: str, image_bytes: bytes | None, image_mime_type: str | None):
    if image_bytes is None:
        return text
    return [{"mime_type": image_mime_type or "image/jpeg", "data": image_bytes}, text]
