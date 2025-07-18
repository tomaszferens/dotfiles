-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = LazyVim.safe_keymap_set

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll and recenter" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll and recenter" })

map("n", "<M-,>", "<c-w>5<")
map("n", "<M-.>", "<c-w>5>")
map("n", "<M-y>", "<C-W>+")
map("n", "<M-s>", "<C-W>-")
map("t", "<C-\\>", "<C-\\><C-n>")

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

local function insert_markdown_fence()
  -- 1) figure out where we are
  local win = 0
  local buf = 0
  local row = vim.api.nvim_win_get_cursor(win)[1]

  -- 2) insert the three lines
  vim.api.nvim_buf_set_lines(buf, row, row, false, {
    "```",
    "",
    "```",
  })

  -- 3) move cursor to the blank line
  vim.api.nvim_win_set_cursor(win, { row + 2, 0 })

  vim.cmd("startinsert")
end

vim.keymap.set({ "n", "i" }, "<C-`>", insert_markdown_fence, {
  desc = "Insert Markdown code fence",
  noremap = true,
  silent = true,
})
