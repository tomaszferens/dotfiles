import { basename } from "node:path";
import type { RenderedSegment, SegmentContext } from "./types.js";
import { fg, rainbow, applyColor } from "./theme.js";
import { hasNerdFonts } from "./icons.js";

// Separator between model name and thinking level
const SEP_DOT = " · ";

// Helper to apply semantic color from context
function color(ctx: SegmentContext, semantic: string, text: string): string {
  return fg(ctx.theme, semantic as any, text, ctx.colors);
}

function withIcon(icon: string, text: string): string {
  return icon ? `${icon} ${text}` : text;
}

function formatTokens(n: number): string {
  if (n < 1000) return n.toString();
  if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
  if (n < 1000000) return `${Math.round(n / 1000)}k`;
  if (n < 10000000) return `${(n / 1000000).toFixed(1)}M`;
  return `${Math.round(n / 1000000)}M`;
}

function formatProviderName(provider?: string): string {
  if (!provider) return "";

  const normalized = provider.toLowerCase();

  if (normalized.includes("copilot")) return "github-copilot";
  if (normalized.startsWith("openai")) return "openai";
  if (normalized.startsWith("anthropic")) return "anthropic";
  if (normalized.startsWith("google") || normalized.startsWith("gemini")) return "google";

  return provider;
}

// Thinking level display text
function getThinkingText(level: string): string | undefined {
  const isNerd = hasNerdFonts();
  const THINKING_TEXT: Record<string, string> = isNerd ? {
    minimal: "\u{F0E7} min",
    low: "\u{F10C} low",
    medium: "\u{F192} med",
    high: "\u{F111} high",
    xhigh: "\u{F06D} xhi",
  } : {
    minimal: "[min]",
    low: "[low]",
    medium: "[med]",
    high: "[high]",
    xhigh: "[xhi]",
  };
  return THINKING_TEXT[level];
}

// ═══════════════════════════════════════════════════════════════════════════
// Segment Implementations
// ═══════════════════════════════════════════════════════════════════════════

const piSegment = {
  id: "pi" as const,
  render(ctx: SegmentContext): RenderedSegment {
    if (!ctx.icons.pi) return { content: "", visible: false };
    const content = `${ctx.icons.pi} `;
    return { content: color(ctx, "pi", content), visible: true };
  },
};

const providerSegment = {
  id: "provider" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const providerName = formatProviderName(ctx.model?.provider);
    if (!providerName) {
      return { content: "", visible: false };
    }

    return { content: color(ctx, "provider", providerName), visible: true };
  },
};

const modelSegment = {
  id: "model" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const opts = ctx.options.model ?? {};
    let modelName = ctx.model?.name || ctx.model?.id || "no-model";
    
    // Strip "Claude " prefix for brevity
    if (modelName.startsWith("Claude ")) {
      modelName = modelName.slice(7);
    }

    let content = withIcon(ctx.icons.model, modelName);

    // Add thinking level with dot separator
    if (opts.showThinkingLevel !== false && ctx.model?.reasoning) {
      const level = ctx.thinkingLevel || "off";
      if (level !== "off") {
        const thinkingText = getThinkingText(level);
        if (thinkingText) {
          content += `${SEP_DOT}${thinkingText}`;
        }
      }
    }

    return { content: color(ctx, "model", content), visible: true };
  },
};

const pathSegment = {
  id: "path" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const opts = ctx.options.path ?? {};
    const mode = opts.mode ?? "basename";

    let pwd = process.cwd();
    const home = process.env.HOME || process.env.USERPROFILE;

    if (mode === "basename") {
      pwd = basename(pwd) || pwd;
    } else {
      if (home && pwd.startsWith(home)) {
        pwd = `~${pwd.slice(home.length)}`;
      }
      if (pwd.startsWith("/work/")) {
        pwd = pwd.slice(6);
      }
      if (mode === "abbreviated") {
        const maxLen = opts.maxLength ?? 40;
        if (pwd.length > maxLen) {
          pwd = `…${pwd.slice(-(maxLen - 1))}`;
        }
      }
    }

    const content = withIcon(ctx.icons.folder, pwd);
    return { content: color(ctx, "path", content), visible: true };
  },
};

const gitSegment = {
  id: "git" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const opts = ctx.options.git ?? {};
    const { branch, staged, unstaged, untracked } = ctx.git;
    
    if (!branch && staged === 0 && unstaged === 0 && untracked === 0) {
      return { content: "", visible: false };
    }

    const isDirty = staged > 0 || unstaged > 0 || untracked > 0;
    const showBranch = opts.showBranch !== false;
    const branchColor = isDirty ? "gitDirty" : "gitClean";

    let content = "";
    if (showBranch && branch) {
      content = color(ctx, branchColor, withIcon(ctx.icons.branch, branch));
    }

    const indicators: string[] = [];
    if (opts.showUnstaged !== false && unstaged > 0) {
      indicators.push(applyColor(ctx.theme, "warning", `*${unstaged}`));
    }
    if (opts.showStaged !== false && staged > 0) {
      indicators.push(applyColor(ctx.theme, "success", `+${staged}`));
    }
    if (opts.showUntracked !== false && untracked > 0) {
      indicators.push(applyColor(ctx.theme, "muted", `?${untracked}`));
    }
    
    if (indicators.length > 0) {
      const indicatorText = indicators.join(" ");
      if (!content && showBranch === false) {
        content = color(ctx, branchColor, ctx.icons.git ? `${ctx.icons.git} ` : "") + indicatorText;
      } else {
        content += content ? ` ${indicatorText}` : indicatorText;
      }
    }

    if (!content) return { content: "", visible: false };
    return { content, visible: true };
  },
};

const thinkingSegment = {
  id: "thinking" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const level = ctx.thinkingLevel || "off";
    
    // Don't show thinking segment when it's off
    if (level === "off") {
      return { content: "", visible: false };
    }
    
    const opts = ctx.options.thinking ?? {};

    const levelText: Record<string, string> = {
      minimal: "min",
      low: "low",
      medium: "med",
      high: "high",
      xhigh: "xhigh",
    };
    const label = levelText[level] || level;
    
    const prefix = opts.prefix ?? "";
    const text = prefix ? `${prefix}${label}` : label;
    const content = withIcon(ctx.icons.thinking, text);

    if (level === "high" || level === "xhigh") {
      return { content: rainbow(content), visible: true };
    }

    return { content: color(ctx, "thinking", content), visible: true };
  },
};

const tokenInSegment = {
  id: "token_in" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { input } = ctx.usageStats;
    if (!input) return { content: "", visible: false };
    const content = withIcon(ctx.icons.input, formatTokens(input));
    return { content: color(ctx, "tokens", content), visible: true };
  },
};

const tokenOutSegment = {
  id: "token_out" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { output } = ctx.usageStats;
    if (!output) return { content: "", visible: false };
    const content = withIcon(ctx.icons.output, formatTokens(output));
    return { content: color(ctx, "tokens", content), visible: true };
  },
};

const tokenTotalSegment = {
  id: "token_total" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { input, output, cacheRead, cacheWrite } = ctx.usageStats;
    const total = input + output + cacheRead + cacheWrite;
    if (!total) return { content: "", visible: false };
    const content = withIcon(ctx.icons.tokens, formatTokens(total));
    return { content: color(ctx, "tokens", content), visible: true };
  },
};

const costSegment = {
  id: "cost" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { cost } = ctx.usageStats;
    const usingSubscription = ctx.usingSubscription;

    if (!cost && !usingSubscription) {
      return { content: "", visible: false };
    }

    const costDisplay = usingSubscription ? "(sub)" : `$${cost.toFixed(2)}`;
    return { content: color(ctx, "cost", costDisplay), visible: true };
  },
};

const contextPctSegment = {
  id: "context_pct" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const pct = ctx.contextPercent;
    const window = ctx.contextWindow;
    const opts = ctx.options.context_pct ?? {};

    const showAuto = opts.showAutoIcon !== false && ctx.icons.auto;
    const autoIcon = ctx.autoCompactEnabled && showAuto ? ` ${ctx.icons.auto}` : "";
    const text = `${pct.toFixed(1)}%/${formatTokens(window)}${autoIcon}`;

    let content: string;
    if (pct > 90) {
      content = withIcon(ctx.icons.contextPct, color(ctx, "contextError", text));
    } else if (pct > 70) {
      content = withIcon(ctx.icons.contextPct, color(ctx, "contextWarn", text));
    } else {
      content = withIcon(ctx.icons.contextPct, color(ctx, "context", text));
    }

    return { content, visible: true };
  },
};

const contextTotalSegment = {
  id: "context_total" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const window = ctx.contextWindow;
    if (!window) return { content: "", visible: false };
    return {
      content: color(ctx, "context", withIcon(ctx.icons.contextTotal, formatTokens(window))),
      visible: true,
    };
  },
};

const cacheReadSegment = {
  id: "cache_read" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { cacheRead } = ctx.usageStats;
    if (!cacheRead) return { content: "", visible: false };
    const content = withIcon(ctx.icons.cacheRead, formatTokens(cacheRead));
    return { content: color(ctx, "tokens", content), visible: true };
  },
};

const cacheWriteSegment = {
  id: "cache_write" as const,
  render(ctx: SegmentContext): RenderedSegment {
    const { cacheWrite } = ctx.usageStats;
    if (!cacheWrite) return { content: "", visible: false };
    const content = withIcon(ctx.icons.cacheWrite, formatTokens(cacheWrite));
    return { content: color(ctx, "tokens", content), visible: true };
  },
};

const separatorSegment = {
  id: "separator" as const,
  render(ctx: SegmentContext): RenderedSegment {
    return { content: ctx.icons.separator, visible: true };
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// Segment Registry
// ═══════════════════════════════════════════════════════════════════════════

const SEGMENTS = {
  pi: piSegment,
  provider: providerSegment,
  model: modelSegment,
  path: pathSegment,
  git: gitSegment,
  thinking: thinkingSegment,
  token_in: tokenInSegment,
  token_out: tokenOutSegment,
  token_total: tokenTotalSegment,
  cost: costSegment,
  context_pct: contextPctSegment,
  context_total: contextTotalSegment,
  cache_read: cacheReadSegment,
  cache_write: cacheWriteSegment,
  separator: separatorSegment,
};

export function renderSegment(id: StatusLineSegmentId, ctx: SegmentContext): RenderedSegment {
  // Handle custom text segments: "text:Hello World"
  if (id.startsWith("text:")) {
    const text = id.slice(5);
    return { content: text, visible: text.length > 0 };
  }

  const segment = SEGMENTS[id as keyof typeof SEGMENTS];
  if (!segment) {
    return { content: "", visible: false };
  }
  return segment.render(ctx);
}
