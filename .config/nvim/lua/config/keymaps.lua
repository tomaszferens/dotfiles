-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = LazyVim.safe_keymap_set

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll and recenter" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll and recenter" })

map("n", "<M-,>", "<c-w>5<")
map("n", "<M-.>", "<c-w>5>")
map("n", "<M-t>", "<C-W>+")
map("n", "<M-s>", "<C-W>-")

map(
  "n",
  "<leader>zc",
  ":call setreg('+', expand('%:.') .. ':' .. line('.'))<CR>",
  { desc = "Copy file path to clipboard" }
)

map("v", "<leader>ad", [[:'<,'>CodeCompanionChat Add<CR>]], { noremap = true, silent = true })
map(
  { "n", "v" },
  "<leader>ac",
  "<cmd>CodeCompanionActions<cr>",
  { noremap = true, silent = true, desc = "CodeCompanion actions" }
)
map(
  { "n", "v" },
  "<leader>aa",
  "<cmd>CodeCompanionChat Toggle<cr>",
  { noremap = true, silent = true, desc = "CodeCompanion chat" }
)
map("v", "<leader>ae", function()
  vim.ui.input({
    prompt = "Enter prompt: ",
    relative = "cursor",
    override = function(conf)
      conf.anchor = "NW"
      conf.row = 1
      return conf
    end,
  }, function(prompt)
    if not prompt or prompt == "" then
      print("No prompt given. Aborting.")
      return
    end
    vim.cmd("'<,'>CodeCompanion Please edit the selected code. Here is a full #buffer code for reference. " .. prompt)
  end)
end, { noremap = true, silent = true, desc = "Edit" })
map({ "n" }, "<leader>ab", function()
  vim.cmd("CodeCompanionChat")
  vim.cmd("startinsert")
  vim.api.nvim_feedkeys("#buffer ", "n", true)
end, { noremap = true, silent = true, desc = "Chat with buffer" })
map({ "n" }, "<leader>ae", function()
  vim.cmd("CodeCompanionChat")
  vim.cmd("startinsert")
  vim.api.nvim_feedkeys("#buffer @editor ", "n", true)
end, { noremap = true, silent = true, desc = "Edit buffer" })

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
