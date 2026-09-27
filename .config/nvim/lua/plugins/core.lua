return {
  { "ellisonleao/gruvbox.nvim", opts = {
    contrast = "soft",
  } },
  {
    "rebelot/kanagawa.nvim",
  },
  { "EdenEast/nightfox.nvim" },
  { "rose-pine/neovim" },
  { "catppuccin/nvim", name = "catppuccin" },
  { "projekt0n/github-nvim-theme", name = "github-theme" },
  {
    "LazyVim/LazyVim",
    opts = {
      -- colorscheme = "catppuccin-macchiato",
      colorscheme = function()
        require("utils.theme").apply()
      end,
    },
  },
}
