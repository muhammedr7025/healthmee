from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.prompting import build_system_prompt, build_tool_schema


class AnthropicProvider(LLMProvider):
    def __init__(self, api_key: str, model: str):
        import anthropic

        self._client = anthropic.Anthropic(api_key=api_key)
        self._model = model

    def extract(self, text: str, type_catalog: list[dict]) -> ExtractionResult:
        tool = build_tool_schema(type_catalog)
        system = build_system_prompt(type_catalog)

        response = self._client.messages.create(
            model=self._model,
            max_tokens=1024,
            system=system,
            tools=[tool],
            tool_choice={"type": "tool", "name": "log_entries"},
            messages=[{"role": "user", "content": text}],
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
