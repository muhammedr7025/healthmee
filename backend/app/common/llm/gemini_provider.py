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

    def extract(self, text: str, type_catalog: list[dict]) -> ExtractionResult:
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

        response = model.generate_content(text)
        data = json.loads(response.text)
        entries = [
            ExtractedEntry(type=e["type"], payload=e.get("payload", {}), summary=e.get("summary", ""))
            for e in data.get("entries", [])
        ]
        return ExtractionResult(entries=entries, reply=data.get("reply", ""))
