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

-- Wezterm pane keybindings
local ai_utils = require("utils.ai")


map("n", "<M-a>", function()
  ai_utils.send_file()
end, { desc = "Send file path to bottom pane" })

map({ "x", "v" }, "<M-a>", function()
  ai_utils.send_visual_reference()
end, { desc = "Send file+lines to bottom pane" })

map("n", "<leader>af", function()
  ai_utils.send_file()
end, { desc = "Send File" })

map("x", "<leader>av", function()
  ai_utils.send("{selection}")
end, { desc = "Send Selection" })
