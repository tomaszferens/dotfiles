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

-- Start a known server so wezterm can query neovim for current file
local server_path = "/tmp/nvim-wezterm.sock"
pcall(vim.fn.delete, server_path)
pcall(vim.fn.serverstart, server_path)
vim.g.ai_cmp = false

-- diff line backgrounds
vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#34462F" })
vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#462F2F" })
vim.api.nvim_set_hl(0, "DiffChange", { bg = "#2F4146" })
vim.api.nvim_set_hl(0, "DiffText", { bg = "#463C2F" })

-- vim.api.nvim_set_hl(0, "SnacksPickerDir", { fg = "#939ec9" })
-- vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = "#939ec9" })
-- vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { link = "Comment" })
-- vim.api.nvim_set_hl(0, "SnacksPickerGitStatusUntracked", { link = "Special" })
