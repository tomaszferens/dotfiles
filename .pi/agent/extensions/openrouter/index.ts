import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerProvider("openrouter", {
    baseUrl: "https://openrouter.ai/api/v1",
    apiKey: "OPENROUTER_API_KEY", // env var name
    authHeader: true, // adds Authorization: Bearer header
    api: "openai-completions",
    models: [
      {
        id: "anthropic/claude-3.5-sonnet",
        name: "Claude 3.5 Sonnet (OpenRouter)",
        reasoning: false,
        input: ["text", "image"],
        cost: {
          input: 3.0,
          output: 15.0,
          cacheRead: 0,
          cacheWrite: 0,
        },
        contextWindow: 200000,
        maxTokens: 8192,
      },
      {
        id: "deepseek/deepseek-chat",
        name: "DeepSeek Chat (OpenRouter)",
        reasoning: false,
        input: ["text"],
        cost: {
          input: 0.27,
          output: 1.1,
          cacheRead: 0,
          cacheWrite: 0,
        },
        contextWindow: 64000,
        maxTokens: 8192,
      },
      {
        id: "openai/gpt-5.3-codex",
        name: "GPT-5.3 Codex (OpenRouter)",
        reasoning: true,
        input: ["text", "image"],
        cost: {
          input: 5.0, // Check OpenRouter for exact pricing
          output: 15.0,
          cacheRead: 0,
          cacheWrite: 0,
        },
        contextWindow: 128000,
        maxTokens: 16384,
      },
      {
        id: "moonshotai/kimi-k2.5",
        name: "MoonshotAI: Kimi K2.5 (OpenRouter)",
        reasoning: false,
        input: ["text"],
        cost: {
          input: 0.45,
          output: 2.2,
          cacheRead: 0,
          cacheWrite: 0,
        },
        contextWindow: 262144,
        maxTokens: 8192,
      },
      // Add more models as needed - check https://openrouter.ai/docs#models
    ],
  });
}
