local function focus_claude_code_window(text)
  text = text or ""
  local windows = vim.api.nvim_list_wins()

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)

    -- More specific pattern matching for your example
    if buf_name:find("/claude%-code%-%-") then
      vim.api.nvim_set_current_win(win)

      if text ~= "" then
        -- Go to the end of the buffer (optional)
        vim.api.nvim_feedkeys("G", "n", false)

        -- Enter insert mode at the end of the line
        vim.api.nvim_feedkeys("A", "n", false)

        -- Type your content
        vim.api.nvim_feedkeys(text, "n", false)
      end

      return true
    end
  end

  return false
end

return {
  "greggh/claude-code.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for git operations
  },
  config = function()
    require("claude-code").setup({
      window = {
        split_ratio = 0.5,
        position = "vertical",
      },
    })

    local map = LazyVim.safe_keymap_set
    map("n", "<C-,>", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      vim.cmd("ClaudeCode")
      vim.defer_fn(function()
        vim.api.nvim_feedkeys(
          "I'm currently looking at this buffer: " .. "@" .. relative_buffer_path .. "\n",
          "n",
          true
        )
      end, 1000)
    end, { desc = "Open claude code" })
    map("n", "<C-;>", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      focus_claude_code_window("@" .. relative_buffer_path .. "\n")
    end, { desc = "Add to claude code" })
  end,
}
