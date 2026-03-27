return {
  dir = "~/terminal-manager.nvim",
  lazy = false,
  dependencies = { "MunifTanjim/nui.nvim" },
  config = function()
    require("terminal-manager").setup({
      display_mode = "horizontal",
      size = 35,
      zindex = 250,
      escape_key = false,
    })

    vim.api.nvim_create_autocmd("TermOpen", {
      callback = function()
        vim.schedule(function()
          local chan = vim.b.terminal_job_id
          if chan then
            vim.fn.chansend(chan, "pwd\n")
          end
        end)
      end,
    })
  end,
  keys = {
    { "<A-c>", "<cmd>TerminalManagerToggle<cr>", mode = { "n", "t" } },
    { "<A-n>", "<cmd>TerminalManagerNew<cr>", mode = { "n", "t" } },
    { "<A-x>", "<cmd>TerminalManagerClose<cr>", mode = { "n", "t" } },
    { "<A-[>", "<cmd>TerminalManagerPrev<cr>", mode = { "n", "t" } },
    { "<A-]>", "<cmd>TerminalManagerNext<cr>", mode = { "n", "t" } },
    { "<M-l>", "<cmd>TerminalManagerCycleLayout<cr>", mode = { "n", "t" } },
    {
      "<M-a>",
      function()
        require("utils.ai").send_file()
      end,
      desc = "Send file to terminal",
      mode = { "n" },
    },
    {
      "<M-a>",
      function()
        require("utils.ai").send_visual_reference()
      end,
      desc = "Send file+lines to terminal",
      mode = { "x", "v" },
    },
    {
      "<S-CR>",
      function()
        require("utils.ai").send("\n")
      end,
      desc = "New line",
      mode = { "t" },
    },
    {
      "<leader>af",
      function()
        require("utils.ai").send_file()
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("utils.ai").send("{selection}")
      end,
      mode = { "x" },
      desc = "Send Selection",
    },
  },
}
