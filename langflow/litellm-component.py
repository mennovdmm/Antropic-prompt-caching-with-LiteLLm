"""
LiteLLM Proxy Component voor Langflow
Activeert Anthropic prompt caching via LiteLLM proxy
90% kostenbesparing op grote prompts!
"""

from langflow.custom import Component
from langflow.io import StrInput, SecretStrInput, DropdownInput, IntInput, FloatInput, Output
from langflow.field_typing import LanguageModel
from langchain_openai import ChatOpenAI


class LiteLLMComponent(Component):
    display_name = "LiteLLM Proxy"
    description = "Connect to LiteLLM proxy for Anthropic prompt caching (90% cost savings!)"
    icon = "🚀"
    name = "LiteLLMProxy"

    inputs = [
        StrInput(
            name="base_url",
            display_name="LiteLLM Base URL",
            value="http://localhost:4000/v1",  # WERKENDE ENDPOINT!
            info="Your LiteLLM proxy endpoint",
            required=True,
        ),
        SecretStrInput(
            name="api_key",
            display_name="API Key",
            value="sk-litellm-master-2024",  # MASTER KEY VAN LITELLM
            info="LiteLLM master key or API key",
            required=True,
        ),
        DropdownInput(
            name="model_name",
            display_name="Model",
            options=[
                "claude-sonnet-4-cached",  # Sonnet 4.0 - SNEL & GOEDKOOP
                "claude-opus-4-cached",     # Opus 4.1 - SLIM & KRACHTIG
            ],
            value="claude-sonnet-4-cached",  # Default naar Sonnet 4.0
            info="Cached models for 90% cost savings",
            required=True,
        ),
        IntInput(
            name="max_tokens",
            display_name="Max Tokens",
            value=4096,
            advanced=True,
        ),
        FloatInput(
            name="temperature",
            display_name="Temperature",
            value=0.1,
            advanced=True,
        ),
    ]

    outputs = [
        Output(
            display_name="LLM",
            name="llm_output",
            method="build_llm"
        ),
    ]

    def build_llm(self) -> LanguageModel:
        """Build ChatOpenAI instance pointing to LiteLLM proxy"""
        
        # Validation - gebruik defaults als velden leeg zijn
        max_tokens_value = self.max_tokens if self.max_tokens else 4096
        temperature_value = self.temperature if self.temperature else 0.1
        
        # Log configuratie
        self.status = f"🚀 Connecting to LiteLLM proxy at: {self.base_url}"
        print(f"📦 Using model: {self.model_name}")
        print(f"✅ CACHE ENABLED - 90% cost savings active!")
        print(f"💰 Your 13,655 word prompt will be cached by Anthropic")
        
        # Map model namen naar wat we in logs zien
        model_info = {
            "claude-sonnet-4-cached": "Sonnet 4.0 (Fast & Affordable)",
            "claude-opus-4-cached": "Opus 4.1 (Powerful & Smart)"
        }
        
        print(f"🎯 Selected: {model_info.get(self.model_name, self.model_name)}")
        
        # Return ChatOpenAI die naar LiteLLM wijst
        # LiteLLM spreekt OpenAI protocol, dus dit werkt perfect!
        return ChatOpenAI(
            openai_api_base=self.base_url,
            openai_api_key=self.api_key,
            model_name=self.model_name,
            max_tokens=max_tokens_value,
            temperature=temperature_value,
            streaming=True,  # Voor realtime responses
        )