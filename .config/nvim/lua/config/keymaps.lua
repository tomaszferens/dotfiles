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
map("t", "<C-\\>", "<C-\\><C-n>")
map("t", "<M-,>", "<Cmd>vertical resize -5<CR>")
map("t", "<M-.>", "<Cmd>vertical resize +5<CR>")

map({ "n", "t" }, "<C-=>", "<Cmd>wincmd =<CR>", { desc = "Equalize window sizes" })

-- Window navigation in terminal mode
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Navigate to left window" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Navigate to bottom window" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Navigate to top window" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Navigate to right window" })

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

-- Claude Code keybindings
local ai_utils = require("utils.ai")

map({ "n", "i" }, "<M-f>", function()
  ai_utils.focus_terminal()
end, { desc = "Focus AI Terminal (OpenCode/Claude)" })

map("t", "<M-a>", function()
  -- Find first real file buffer that exists on disk and is visible in a window
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buftype = vim.bo[bufnr].buftype
      local buf_name = vim.api.nvim_buf_get_name(bufnr)

      -- Skip special buffers and check if file exists on disk
      if buftype == "" and buf_name ~= "" and not buf_name:match("^term://") and vim.fn.filereadable(buf_name) == 1 then
        local path = vim.fn.fnamemodify(buf_name, ":p")
        ai_utils.add_path_to_ai_terminal(path)
        return
      end
    end
  end
end, { desc = "Add file to AI terminal (Claude/OpenCode)" })

map("t", "<M-v>", function()
  local reg_content = vim.fn.getreg("+")
  local chunks = {}
  local chunk_size = 1000 -- Adjust based on testing

  for i = 1, #reg_content, chunk_size do
    table.insert(chunks, reg_content:sub(i, i + chunk_size - 1))
  end

  local job_id = vim.b.terminal_job_id
  for i, chunk in ipairs(chunks) do
    vim.fn.chansend(job_id, chunk)
    vim.wait(10) -- Small delay between chunks
  end
end, { desc = "Paste clipboard in Claude Code terminal" })
