return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
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
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        node_incremental = "<TAB>",
        node_decremental = "<S-TAB>",
      },
    },
  },
}
