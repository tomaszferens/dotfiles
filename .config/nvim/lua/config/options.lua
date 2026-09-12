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

-- Start a known server so wezterm/tmux/herdr can query neovim for the current
-- file. Inside herdr the socket is workspace-scoped (one Neovim per herdr
-- workspace; the alt+a bridge script finds it by HERDR_WORKSPACE_ID).
-- Otherwise it is per-pane: in tmux, WEZTERM_PANE is the outer terminal pane
-- and is shared by all tmux panes, so prefer TMUX_PANE to avoid collisions.
local server_path
if vim.env.HERDR_WORKSPACE_ID then
  local workspace_id = vim.env.HERDR_WORKSPACE_ID:gsub("[^%w_.-]", "_")
  server_path = "/tmp/nvim-herdr-" .. workspace_id .. ".sock"
else
  local pane_id = vim.env.TMUX_PANE or vim.env.WEZTERM_PANE or "0"
  pane_id = pane_id:gsub("[^%w_.-]", "_")
  server_path = "/tmp/nvim-wezterm-" .. pane_id .. ".sock"
end
pcall(vim.fn.delete, server_path)
pcall(vim.fn.serverstart, server_path)
vim.g.ai_cmp = false
vim.g.lazyvim_ts_lsp = "tsgo"
-- Apply project-specific linter fixes synchronously before formatting and writing.
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
