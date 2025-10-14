return {
  "folke/sidekick.nvim",
  opts = {
    nes = { enabled = false },
  },
  keys = {
    {
      "<c-.>",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "Sidekick Toggle",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<M-a>",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Add file to AI terminal",
    },
    {
      "<M-c>",
      function()
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "Add file to AI terminal",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<S-CR>",
      function()
        vim.api.nvim_feedkeys("\\", "n", false)
        vim.defer_fn(function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end, 0)
      end,
      desc = "New line in AI terminal",
      mode = { "t" },
    },
    {
      "<M-o>",
      function()
        require("sidekick.cli").toggle({ name = "opencode", focus = true })
      end,
      desc = "Add file to AI terminal",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("sidekick.cli").send({ msg = "{selection}" })
      end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
  },
}
