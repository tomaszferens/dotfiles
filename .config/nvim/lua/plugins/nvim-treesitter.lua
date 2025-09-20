return {
  {
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
  },
  {
    "MeanderingProgrammer/treesitter-modules.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ---@module 'treesitter-modules'
    ---@type ts.mod.UserConfig
    opts = {
      incremental_selection = {
        enable = true,
        keymaps = {
          node_incremental = "<tab>",
          node_decremental = "<s-tab>",
        },
      },
    },
  },
}
