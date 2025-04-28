return {
  "sindrets/diffview.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    { "<C-g>", "<CMD>DiffviewOpen<CR>", mode = { "n" } },
    { "<leader>gf", "<CMD>DiffviewFileHistory %<CR>", mode = { "n" }, desc = "Current file history" },
    { "<leader>ghh", "<CMD>DiffviewFileHistory<CR>", mode = { "n" }, desc = "Current branch history" },
  },
  config = function()
    require("diffview").setup({
      keymaps = {
        view = {
          ["<C-g>"] = "<CMD>DiffviewClose<CR>",
        },
        file_panel = {
          ["<C-g>"] = "<CMD>DiffviewClose<CR>",
          {
            "n",
            "gf",
            function()
              local path = require("diffview.lib").get_current_view().panel:get_item_at_cursor().absolute_path
              vim.cmd("DiffviewClose")
              vim.cmd(string.format("edit %s", vim.fn.fnameescape(path)))
            end,
            { desc = "Open file in previous tab and close current tab" },
          },
        },
      },
      opts = {
        enhanced_diff_hl = true,
        use_icons = true,
        view = {
          default = { layout = "diff2_horizontal" },
          merge_tool = {
            layout = "diff4_mixed",
          },
        },
      },
    })
  end,
}
