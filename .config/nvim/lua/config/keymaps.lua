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

local markdown_utils = require("utils.markdown")

vim.keymap.set({ "n", "i" }, "<C-`>", markdown_utils.insert_fence, {
  desc = "Insert Markdown code fence",
  noremap = true,
  silent = true,
})

-- Claude Code keybindings
local claude_utils = require("utils.claude")
local utils = require("utils.util")

map({ "n", "v" }, "<M-a>", function()
  -- Check if we're in a snacks picker (this will be overridden by explorer keybinding when in explorer)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Visual mode (v, V, or ^V) - send selection to AI terminals
    claude_utils.send_visual_selection_to_ai_terminals()
  else
    -- Normal mode - add current file to AI terminals
    local current_file = vim.fn.expand("%:p")
    claude_utils.add_file_to_ai_terminals(current_file)
  end
end, { desc = "Send to AI terminal (Claude/OpenCode)" })

map("t", "<S-CR>", function()
  vim.api.nvim_feedkeys("\\", "n", false)
  vim.defer_fn(function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
  end, 5)
end, { desc = "New line in Claude Code" })

map({ "n", "i" }, "<M-f>", function()
  -- Define terminal configurations in priority order
  -- OpenCode first (if visible), then Claude Code
  local terminal_configs = {
    {
      names = { "opencode" },
      create_command = function()
        require("opencode").toggle()
      end,
    },
    {
      names = { "claude", "ClaudeCode" },
      create_command = function()
        vim.cmd("ClaudeCode")
      end,
    },
  }

  utils.focus_or_create_terminal(terminal_configs)
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
        claude_utils.add_file_to_ai_terminals(vim.fn.fnamemodify(buf_name, ":p"))
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
