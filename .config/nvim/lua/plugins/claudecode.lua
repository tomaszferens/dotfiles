return {
  "coder/claudecode.nvim",
  config = true,
  event = "VeryLazy",
  keys = {
    { "<leader>cc", nil, desc = "AI/Claude Code" },
    { "<leader>cct", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>ccr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>ccc", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    {
      "<leader>cca",
      function()
        -- Check if we're in a snacks picker (this will be overridden by explorer keybinding when in explorer)
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" or mode == "\22" then
          -- Visual mode (v, V, or ^V)
          vim.cmd("ClaudeCodeSend")
        else
          -- Normal mode - add current file
          local current_file = vim.fn.expand("%:p")
          vim.cmd("ClaudeCodeAdd " .. current_file)
        end
      end,
      mode = { "n", "v" },
      desc = "Send to Claude",
    },
    {
      "<S-CR>",
      function()
        vim.api.nvim_feedkeys("\\", "n", false)
        vim.defer_fn(function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end, 5)
      end,
      mode = "t",
      desc = "New line in Claude Code",
    },
  },
  opts = {
    terminal = {
      split_width_percentage = 0.50,
    },
  },
}
