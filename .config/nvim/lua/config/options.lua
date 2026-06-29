-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.fillchars = {
  diff = "╱",
}

vim.opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "context:12",
  "algorithm:histogram",
  "linematch:200",
  "indent-heuristic",
}

vim.opt.relativenumber = false

-- Start a known server so wezterm/tmux can query neovim for current file (per-pane).
-- In tmux, WEZTERM_PANE is the outer terminal pane and is shared by all tmux
-- panes, so prefer TMUX_PANE to avoid socket collisions.
local pane_id = vim.env.TMUX_PANE or vim.env.WEZTERM_PANE or "0"
pane_id = pane_id:gsub("[^%w_.-]", "_")
local server_path = "/tmp/nvim-wezterm-" .. pane_id .. ".sock"
pcall(vim.fn.delete, server_path)
pcall(vim.fn.serverstart, server_path)
vim.g.ai_cmp = false
vim.g.lazyvim_ts_lsp = "tsgo"
-- Use an explicit synchronous source.fixAll.eslint autocmd instead of ESLint's
-- formatting provider, so fixes are applied before the file is written.
vim.g.lazyvim_eslint_auto_format = false

-- diff line backgrounds
vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#34462F" })
vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#462F2F" })
vim.api.nvim_set_hl(0, "DiffChange", { bg = "#2F4146" })
vim.api.nvim_set_hl(0, "DiffText", { bg = "#463C2F" })

-- vim.api.nvim_set_hl(0, "SnacksPickerDir", { fg = "#939ec9" })
-- vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = "#939ec9" })
-- vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { link = "Comment" })
-- vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { link = "Special" })
