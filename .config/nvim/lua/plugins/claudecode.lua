return {
  "coder/claudecode.nvim",
  config = true,
  event = "VeryLazy",
  keys = {
    { "<leader>cc", nil, desc = "AI/Claude Code" },
    { "<M-c>", "<cmd>ClaudeCode<cr>", mode = { "n", "i", "t" }, desc = "Toggle Claude" },
    { "<leader>ccr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>ccc", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
  },
  opts = {
    terminal_cmd = "~/.claude/local/claude",
    terminal = {
      split_width_percentage = 0.50,
    },
    diff_opts = {
      keep_terminal_focus = true,
    },
  },
}
