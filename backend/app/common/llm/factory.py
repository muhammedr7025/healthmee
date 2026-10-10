from flask import current_app

from app.common.llm.base import LLMProvider
from app.common.llm.mock_provider import MockProvider

_provider_instance: LLMProvider | None = None


def get_llm_provider() -> LLMProvider:
    global _provider_instance
    if _provider_instance is not None:
        return _provider_instance

    provider_name = current_app.config["LLM_PROVIDER"]
    timeout = float(current_app.config.get("LLM_TIMEOUT_SECONDS", 20))

    if provider_name == "anthropic" and current_app.config.get("ANTHROPIC_API_KEY"):
        from app.common.llm.anthropic_provider import AnthropicProvider

        _provider_instance = AnthropicProvider(
            api_key=current_app.config["ANTHROPIC_API_KEY"],
            model=current_app.config["ANTHROPIC_MODEL"],
            timeout=timeout,
        )
    elif provider_name == "openai" and current_app.config.get("OPENAI_API_KEY"):
        from app.common.llm.openai_provider import OpenAIProvider

        _provider_instance = OpenAIProvider(
            api_key=current_app.config["OPENAI_API_KEY"],
            model=current_app.config["OPENAI_MODEL"],
            timeout=timeout,
        )
    elif provider_name == "gemini" and current_app.config.get("GOOGLE_API_KEY"):
        from app.common.llm.gemini_provider import GeminiProvider

        _provider_instance = GeminiProvider(
            api_key=current_app.config["GOOGLE_API_KEY"],
            model=current_app.config["GOOGLE_MODEL"],
            timeout=timeout,
        )
    else:
        if provider_name != "mock":
            current_app.logger.warning("LLM_PROVIDER=%s but its API key is missing; running the offline extractor", provider_name)
        _provider_instance = MockProvider()

    current_app.logger.info("LLM provider: %s (%s)", _provider_instance.name, _provider_instance.model_name or "offline")
    return _provider_instance


def reset_llm_provider_cache() -> None:
    """Test hook — forces the next get_llm_provider() call to re-resolve."""
    global _provider_instance
    _provider_instance = None
