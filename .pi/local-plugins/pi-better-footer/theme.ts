import type { Theme, ThemeColor } from "@mariozechner/pi-coding-agent";
import type { ColorScheme, ColorValue, SemanticColor } from "./types.js";

// Default color scheme
const DEFAULT_COLORS: Required<ColorScheme> = {
  pi: "accent",
  provider: "muted",
  model: "#d787af",
  path: "#00afaf",
  git: "success",
  gitDirty: "warning",
  gitClean: "success",
  thinking: "muted",
  thinkingHigh: "accent",
  context: "dim",
  contextWarn: "warning",
  contextError: "error",
  cost: "text",
  tokens: "muted",
  separator: "dim",
};

// Rainbow colors for high thinking levels
const RAINBOW_COLORS = [
  "#b281d6", "#d787af", "#febc38", "#e4c00f",
  "#89d281", "#00afaf", "#178fb9", "#b281d6",
];

function isHexColor(color: ColorValue): color is `#${string}` {
  return typeof color === "string" && color.startsWith("#");
}

function hexToAnsi(hex: string): string {
  const h = hex.replace("#", "");
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `\x1b[38;2;${r};${g};${b}m`;
}

export function applyColor(
  theme: Theme,
  color: ColorValue,
  text: string
): string {
  if (isHexColor(color)) {
    return `${hexToAnsi(color)}${text}\x1b[0m`;
  }
  return theme.fg(color as ThemeColor, text);
}

export function fg(
  theme: Theme,
  semantic: SemanticColor,
  text: string,
  presetColors?: ColorScheme
): string {
  const color = presetColors?.[semantic] ?? DEFAULT_COLORS[semantic];
  return applyColor(theme, color, text);
}

export function rainbow(text: string): string {
  let result = "";
  let colorIndex = 0;
  for (const char of text) {
    if (char === " " || char === ":") {
      result += char;
    } else {
      result += hexToAnsi(RAINBOW_COLORS[colorIndex % RAINBOW_COLORS.length]) + char;
      colorIndex++;
    }
  }
  return result + "\x1b[0m";
}

export function getDefaultColors(): Required<ColorScheme> {
  return { ...DEFAULT_COLORS };
}
