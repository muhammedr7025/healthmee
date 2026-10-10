from flask import current_app

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.common.llm.json_utils import parse_json_loose
from app.common.llm.lab_report import EMPTY_REPORT, LAB_REPORT_PROMPT, normalise_lab_report
from app.common.llm.prompting import build_system_prompt


class GeminiProvider(LLMProvider):
    """Uses Gemini's JSON output mode with the shape specified in the prompt,
    rather than function calling or a rigid response_schema.
    """

    name = "gemini"
    _request_options = {"timeout": 20}  # class default so test doubles built without __init__ still work

    def __init__(self, api_key: str, model: str, timeout: float = 20.0):
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        self._genai = genai
        self._model_name = model
        self.model_name = model
        self._request_options = {"timeout": timeout}

    def extract(
        self,
        text: str,
        type_catalog: list[dict],
        image_bytes: bytes | None = None,
        image_mime_type: str | None = None,
        local_now=None,
    ) -> ExtractionResult:
        type_names = [t["name"] for t in type_catalog]
        # Deliberately NOT using response_schema: the entry payload differs per
        # log type, so it's an object with no fixed properties — and Gemini
        # rejects an OBJECT schema without properties. JSON mode plus an
        # explicit shape in the prompt gets the same result without that limit.
        system = (
            f"{build_system_prompt(type_catalog, local_now=local_now)}\n\n"
            "Respond with JSON only, in exactly this shape:\n"
            '{"entries": [{"type": "<one of: ' + ", ".join(type_names) + '>", '
            '"payload": {<fields for that type>}, "summary": "<short one-liner>", '
            '"occurred_at": "<local ISO 8601 date-time, ONLY if the message says when; otherwise omit the key>"}], '
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
            response = model.generate_content(content, request_options=self._request_options)
            data = parse_json_loose(response.text)
        except (ValueError, TypeError) as first_error:
            try:
                response = model.generate_content(content, request_options=self._request_options)
                data = parse_json_loose(response.text)
            except (ValueError, TypeError):
                raise first_error

        if not isinstance(data, dict):
            data = {}
        entries = [
            ExtractedEntry(
                type=e["type"],
                payload=e.get("payload", {}) or {},
                summary=e.get("summary", ""),
                occurred_at=e.get("occurred_at") or None,
            )
            for e in (data.get("entries") or [])
            if isinstance(e, dict) and e.get("type") in type_names
        ]
        return ExtractionResult(entries=entries, reply=data.get("reply", ""), usage=_usage(response))

    def read_lab_report(self, file_bytes: bytes, mime_type: str) -> dict:
        """Photos and PDFs alike — Gemini takes application/pdf inline, so a
        report downloaded from a hospital portal needs no rasterising."""
        try:
            model = self._genai.GenerativeModel(
                self._model_name,
                generation_config={"response_mime_type": "application/json", "temperature": 0},
            )
            response = model.generate_content(
                _content(LAB_REPORT_PROMPT, file_bytes, mime_type), request_options={"timeout": 45}
            )
            self.last_usage = _usage(response)
            return normalise_lab_report(parse_json_loose(response.text))
        except Exception:
            current_app.logger.exception("gemini lab report read failed")
            return dict(EMPTY_REPORT)

    def narrate(self, prompt: str, stats: dict) -> str:
        try:
            model = self._genai.GenerativeModel(
                self._model_name,
                system_instruction="You are MeMe, a warm, non-clinical health journal companion. Write 2-4 "
                "short sentences, plain prose, no markdown, no diagnosis language.",
            )
            response = model.generate_content(prompt, request_options=self._request_options)
            self.last_usage = _usage(response)
            text = (response.text or "").strip()
            return text or super().narrate(prompt, stats)
        except Exception:
            current_app.logger.exception("gemini narrate failed; using the deterministic summary")
            return super().narrate(prompt, stats)


def _usage(response) -> dict | None:
    meta = getattr(response, "usage_metadata", None)
    if meta is None:
        return None
    return {
        "input_tokens": getattr(meta, "prompt_token_count", None),
        "output_tokens": getattr(meta, "candidates_token_count", None),
    }


def _content(text: str, image_bytes: bytes | None, image_mime_type: str | None):
    if image_bytes is None:
        return text
    return [{"mime_type": image_mime_type or "image/jpeg", "data": image_bytes}, text]
