from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.prompting import build_system_prompt


class GeminiProvider(LLMProvider):
    """Uses Gemini's JSON output mode with the shape specified in the prompt,
    rather than function calling or a rigid response_schema.
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
        type_names = [t["name"] for t in type_catalog]
        # Deliberately NOT using response_schema: the entry payload differs per
        # log type, so it's an object with no fixed properties — and Gemini
        # rejects an OBJECT schema without properties. JSON mode plus an
        # explicit shape in the prompt gets the same result without that limit.
        system = (
            f"{build_system_prompt(type_catalog)}\n\n"
            "Respond with JSON only, in exactly this shape:\n"
            '{"entries": [{"type": "<one of: ' + ", ".join(type_names) + '>", '
            '"payload": {<fields for that type>}, "summary": "<short one-liner>"}], '
            '"reply": "<short warm confirmation>"}\n'
            'If nothing is loggable, use {"entries": [], "reply": "..."}.'
        )

        model = self._genai.GenerativeModel(
            self._model_name,
            system_instruction=system,
            # temperature=0: this is literal extraction, not creative writing —
            # determinism is what we want anyway, and it also measurably cut
            # the malformed-JSON rate in testing (observed ~20-30% of calls at
            # the default temperature down to 0/12 at temperature=0).
            generation_config={"response_mime_type": "application/json", "temperature": 0},
        )

        content = _content(text or "What's in this photo? Log it.", image_bytes, image_mime_type)
        # A malformed-JSON response happens occasionally and is a different
        # failure mode
        # from a rate limit or network error: the call itself succeeded, the
        # content just didn't parse. One retry clears most of these cheaply;
        # anything else (quota, auth, network) still propagates immediately
        # so the pipeline falls back to the offline extractor without
        # spending a second request against a wall.
        try:
            response = model.generate_content(content)
            data = parse_json_loose(response.text)
        except (ValueError, TypeError) as first_error:
            try:
                response = model.generate_content(content)
                data = parse_json_loose(response.text)
            except (ValueError, TypeError):
                raise first_error

        entries = [
            ExtractedEntry(type=e["type"], payload=e.get("payload", {}) or {}, summary=e.get("summary", ""))
            for e in (data.get("entries") or [])
            if isinstance(e, dict) and e.get("type") in type_names
        ]
        return ExtractionResult(entries=entries, reply=data.get("reply", ""))

    def extract_lab_values(self, image_bytes: bytes, image_mime_type: str) -> list[dict]:
        try:
            model = self._genai.GenerativeModel(
                self._model_name,
                generation_config={"response_mime_type": "application/json", "temperature": 0},
            )
            content = _content(
                "This is a photo of a lab report. Read every test result you can and return a JSON "
                'array of objects: [{"test_name": str, "value": str, "unit": str or null}]. '
                "Values must be exactly as printed. If you can't read any values, return [].",
                image_bytes,
                image_mime_type,
            )
            response = model.generate_content(content)
            data = parse_json_loose(response.text)
            if isinstance(data, dict):  # some responses wrap the array in a key
                data = next((v for v in data.values() if isinstance(v, list)), [])
            return [
                {"test_name": str(d["test_name"]), "value": str(d["value"]), "unit": d.get("unit")}
                for d in data
                if isinstance(d, dict) and d.get("test_name") and d.get("value") is not None
            ]
        except Exception:
            return []

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            model = self._genai.GenerativeModel(
                self._model_name,
                system_instruction="You are MeMe, a warm, non-clinical health journal companion. Write 2-4 "
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
