return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      worktrees = {
        {
          toplevel = vim.env.HOME,
          gitdir = vim.env.HOME .. "/.cfg",
        },
      },
    },
  },
}
