return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    opts.ensure_installed = opts.ensure_installed or {}
    opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
      "lua",
      "javascript",
      "typescript",
      "tsx",
      "prisma",
      "hcl",
      "terraform",
      "go",
      "gomod",
      "gowork",
      "gosum",
      "yaml",
      "python",
      "css",
    })
    return opts
  end,
}
