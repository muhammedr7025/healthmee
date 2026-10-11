"""Run the golden set against the configured real LLM provider and print
accuracy per case. Not part of CI (costs API calls); run on the server or
with the right keys in the environment:

    LLM_PROVIDER=gemini GOOGLE_API_KEY=... python scripts/eval_live.py
"""

import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app  # noqa: E402
from app.common.llm import get_llm_provider  # noqa: E402
from app.logging.registry import get_type_catalog  # noqa: E402


def main() -> int:
    cases = json.loads((Path(__file__).resolve().parents[1] / "tests" / "golden" / "messages.json").read_text())
    app = create_app()
    passed = 0
    with app.app_context():
        provider = get_llm_provider()
        print(f"provider: {provider.name} ({provider.model_name})")
        for case in cases:
            result = provider.extract(case["text"], get_type_catalog(), local_now=datetime.now())
            got = sorted(e.type for e in result.entries)
            want = sorted(case["types"])
            ok = got == want and (not case.get("question") or bool(result.question))
            passed += ok
            print(f"{'PASS' if ok else 'FAIL'}  {case['text']!r}: got {got} want {want}" + (f"  q={result.question!r}" if result.question else ""))
    print(f"\n{passed}/{len(cases)} cases match on entry types")
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
