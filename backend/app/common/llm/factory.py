from flask import current_app

from app.common.llm.base import LLMProvider
from app.common.llm.mock_provider import MockProvider

_provider_instance: LLMProvider | None = None


def get_llm_provider() -> LLMProvider:
    global _provider_instance
    if _provider_instance is not None:
        return _provider_instance

    provider_name = current_app.config["LLM_PROVIDER"]

    if provider_name == "anthropic" and current_app.config.get("ANTHROPIC_API_KEY"):
        from app.common.llm.anthropic_provider import AnthropicProvider

        _provider_instance = AnthropicProvider(
            api_key=current_app.config["ANTHROPIC_API_KEY"],
            model=current_app.config["ANTHROPIC_MODEL"],
        )
    elif provider_name == "openai" and current_app.config.get("OPENAI_API_KEY"):
        from app.common.llm.openai_provider import OpenAIProvider

        _provider_instance = OpenAIProvider(
            api_key=current_app.config["OPENAI_API_KEY"],
            model=current_app.config["OPENAI_MODEL"],
        )
    elif provider_name == "gemini" and current_app.config.get("GOOGLE_API_KEY"):
        from app.common.llm.gemini_provider import GeminiProvider

        _provider_instance = GeminiProvider(
            api_key=current_app.config["GOOGLE_API_KEY"],
            model=current_app.config["GOOGLE_MODEL"],
        )
    else:
        _provider_instance = MockProvider()

    return _provider_instance


def reset_llm_provider_cache() -> None:
    """Test hook — forces the next get_llm_provider() call to re-resolve."""
    global _provider_instance
    _provider_instance = None
