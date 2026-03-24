export interface IconSet {
  pi: string;
  model: string;
  folder: string;
  branch: string;
  git: string;
  tokens: string;
  contextPct: string;
  contextTotal: string;
  cost: string;
  cacheRead: string;
  cacheWrite: string;
  input: string;
  output: string;
  thinking: string;
  separator: string;
  auto: string;
}

// Nerd Font icons
export const NERD_ICONS: IconSet = {
  pi: "\uE22C",         // nf-oct-pi
  model: "\uEC19",      // nf-md-chip
  folder: "\uF115",     // nf-fa-folder_open
  branch: "\uF126",     // nf-fa-code_fork
  git: "\uF1D3",        // nf-fa-git
  tokens: "\uE26B",     // nf-seti-html
  contextPct: "\uE70F", // nf-dev-database
  contextTotal: "\uE70F", // nf-dev-database
  cost: "\uF155",       // nf-fa-dollar
  cacheRead: "\uF1C0",  // nf-fa-database
  cacheWrite: "\uF1C0", // nf-fa-database
  input: "\uF090",      // nf-fa-sign_in
  output: "\uF08B",     // nf-fa-sign_out
  thinking: "\uEE9C",   // nf-fa-brain
  separator: "\uE0B1",  // nf-pl-left_soft_divider
  auto: "\uF0068",      // nf-md-lightning_bolt
};

// ASCII/Unicode fallback icons
export const ASCII_ICONS: IconSet = {
  pi: "π",
  model: "◈",
  folder: "📁",
  branch: "⎇",
  git: "⎇",
  tokens: "⊛",
  contextPct: "◫",
  contextTotal: "◫",
  cost: "$",
  cacheRead: "↙",
  cacheWrite: "↗",
  input: "↑",
  output: "↓",
  thinking: "🧠",
  separator: "|",
  auto: "⚡",
};

// Detect Nerd Font support
export function hasNerdFonts(): boolean {
  if (process.env.POWERLINE_NERD_FONTS === "1") return true;
  if (process.env.POWERLINE_NERD_FONTS === "0") return false;
  
  if (process.env.GHOSTTY_RESOURCES_DIR) return true;
  
  const term = (process.env.TERM_PROGRAM || "").toLowerCase();
  const nerdTerms = ["iterm", "wezterm", "kitty", "ghostty", "alacritty"];
  return nerdTerms.some(t => term.includes(t));
}

export function getIcons(customIcons?: Partial<IconSet>): IconSet {
  const baseIcons = hasNerdFonts() ? NERD_ICONS : ASCII_ICONS;
  if (!customIcons || Object.keys(customIcons).length === 0) {
    return baseIcons;
  }
  return { ...baseIcons, ...customIcons };
}
