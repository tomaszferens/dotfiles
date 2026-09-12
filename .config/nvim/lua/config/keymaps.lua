-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = LazyVim.safe_keymap_set

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll and recenter" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll and recenter" })

local function resize_height(delta)
  local direction = delta > 0 and "+" or "-"
  vim.cmd(("resize %s%d"):format(direction, math.abs(delta)))
end

map("n", "<M-,>", "<c-w>5<")
map("n", "<M-.>", "<c-w>5>")
map("n", "<M-t>", function() resize_height(5) end, { desc = "Make window taller" })
map("n", "<M-s>", function() resize_height(-5) end, { desc = "Make window smaller" })

map("n", "<C-=>", "<Cmd>wincmd =<CR>", { desc = "Equalize window sizes" })

map(
  "n",
  "<leader>zc",
  ":call setreg('+', expand('%:.') .. ':' .. line('.'))<CR>",
  { desc = "Copy file path to clipboard" }
)

map("n", "<C-a>", "ggVG", { desc = "Select all text (normal mode)" })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all text (insert mode)" })
map({ "n", "i" }, "<C-c>", "<Esc><cmd>%y+<CR>", { desc = "Copy all text", noremap = true, silent = true })

map("n", "]<tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "[<tab>", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

map("n", "<leader>xr", function()
  require("quicker").refresh()
end, { desc = "Refresh Quickfix List" })

local markdown_utils = require("utils.markdown")

vim.keymap.set({ "n", "i" }, "<C-`>", markdown_utils.insert_fence, {
  desc = "Insert Markdown code fence",
  noremap = true,
  silent = true,
})

-- WezTerm/tmux/herdr pane keybindings. Inside herdr the alt+a chord normally
-- arrives via the bridge script rather than as a keypress, but the mappings
-- route to the herdr module too in case the key reaches Neovim directly.
local ai_utils = require("utils.ai")
local herdr_utils = require("utils.herdr")

map({ "n", "x", "v" }, "<M-a>", function()
  if herdr_utils.available() then
    herdr_utils.send_current_reference()
  elseif vim.fn.mode():match("^[vV\22]") then
    ai_utils.send_visual_reference()
  else
    ai_utils.send_file()
  end
end, { desc = "Send file (or file+lines) reference to agent pane" })

map({ "n", "x", "v" }, "<M-b>", function()
  if herdr_utils.available() then
    herdr_utils.send_current_reference_with_prompt()
  elseif vim.fn.mode():match("^[vV\22]") then
    ai_utils.send_visual_reference_with_prompt()
  else
    ai_utils.send_file_with_prompt()
  end
end, { desc = "Prompt AI with file (or file+lines) reference" })

map("n", "<leader>af", function()
  ai_utils.send_file()
end, { desc = "Send File" })

map("x", "<leader>av", function()
  ai_utils.send("{selection}")
end, { desc = "Send Selection" })

-- Fold to a given depth: `<leader>z2` keeps 2 levels open and folds everything
-- deeper, `<leader>z3` keeps 3, etc. `<leader>z0` folds all (like zM).
-- 'foldlevel' is window-local, so the chosen level is remembered per buffer
-- (vim.b.fold_level) and re-applied whenever that buffer is shown in a window.
local default_fold_level = vim.go.foldlevel

for level = 0, 9 do
  map("n", "<leader>z" .. level, function()
    vim.b.fold_level = level
    vim.wo.foldenable = true
    vim.api.nvim_set_option_value("foldlevel", level, { win = 0 })
    vim.cmd("normal! zx")
  end, { desc = "Fold to level " .. level })
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("fold_level_per_buffer", { clear = true }),
  callback = function(ev)
    local level = vim.b[ev.buf].fold_level or default_fold_level
    vim.api.nvim_set_option_value("foldlevel", level, { win = 0 })
  end,
})
