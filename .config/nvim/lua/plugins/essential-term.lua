return {
  "wr9dg17/essential-term.nvim",
  lazy = false,
  dependencies = { "MunifTanjim/nui.nvim" },
  config = function()
    require("essential-term").setup({
      display_mode = "vertical",
      size = 50,
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
    { "<A-t>", "<cmd>EssentialTermToggle<cr>", mode = { "n", "t" } },
    { "<A-m>", "<cmd>EssentialTermNew<cr>", mode = { "n", "t" } },
    { "<A-x>", "<cmd>EssentialTermClose<cr>", mode = { "n", "t" } },
    { "<A-[>", "<cmd>EssentialTermPrev<cr>", mode = { "t" } },
    { "<A-]>", "<cmd>EssentialTermNext<cr>", mode = { "t" } },
    {
      "<c-.>",
      function()
        require("utils.ai").toggle()
      end,
      desc = "Toggle Terminal",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<M-c>",
      function()
        require("utils.ai").toggle()
      end,
      desc = "Toggle Terminal",
      mode = { "n", "t", "i", "x" },
    },
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
