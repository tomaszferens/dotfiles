return {
  "gbprod/substitute.nvim",
  event = "VeryLazy",
  config = function()
    require("substitute").setup({})

    local map = LazyVim.safe_keymap_set

    map("n", "<leader>r", require("substitute").operator, { noremap = true })
    map("n", "<leader>rr", require("substitute").line, { noremap = true })
    map("n", "<leader>R", require("substitute").eol, { noremap = true })
    map("x", "<leader>r", require("substitute").visual, { noremap = true })
  end,
}
