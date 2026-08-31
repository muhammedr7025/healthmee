import json

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class OpenAIProvider(LLMProvider):
    def __init__(self, api_key: str, model: str):
        from openai import OpenAI

        self._client = OpenAI(api_key=api_key)
        self._model = model

    def extract(self, text: str, type_catalog: list[dict]) -> ExtractionResult:
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
                {"role": "user", "content": text},
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
