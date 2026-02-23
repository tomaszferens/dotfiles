return {
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        hover = { silent = true },
      },
      routes = {
        { filter = { find = "Failed to watch.*%.git" }, opts = { skip = true } },
      },
    },
  },
}
