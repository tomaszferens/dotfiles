return {
  {
    "nvim-tree/nvim-web-devicons",
    opts = {},
    event = "VeryLazy",
  },
  {
    "SmiteshP/nvim-navic",
    event = "VeryLazy",
  },
  {
    "b0o/incline.nvim",
    config = function()
      local helpers = require("incline.helpers")
      local navic = require("nvim-navic")
      local devicons = require("nvim-web-devicons")
      require("incline").setup({
        window = {
          padding = 0,
          margin = { horizontal = 0, vertical = 0 },
        },
        hide = {
          only_win = true,
        },
        ignore = {
          wintypes = function(winid)
            -- 1. Find the tabpage this window belongs to
            local tab = vim.api.nvim_win_get_tabpage(winid)
            local wintype = vim.fn.win_gettype(winid)

            -- 2. Iterate every window in that tab
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
              local b = vim.api.nvim_win_get_buf(w)
              local name = vim.api.nvim_buf_get_name(b)
              -- 3. If any buffer-name starts with "diffview://", ignore
              if name:match("^diffview://") then
                return true
              end
            end

            if wintype ~= "" then
              return true
            end

            return false
          end,
        },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          if filename == "" then
            filename = "[No Name]"
          end
          local ft_icon, ft_color = devicons.get_icon_color(filename)
          local modified = vim.bo[props.buf].modified
          local res = {
            ft_icon and { " ", ft_icon, " ", guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or "",
            " ",
            { filename, gui = modified and "bold,italic" or "bold" },
            guibg = "#44406e",
          }
          if props.focused then
            for _, item in ipairs(navic.get_data(props.buf) or {}) do
              table.insert(res, {
                { " > ", group = "NavicSeparator" },
                { item.icon, group = "NavicIcons" .. item.type },
                { item.name, group = "NavicText" },
              })
            end
          end
          table.insert(res, " ")
          return res
        end,
      })
    end,
    -- Optional: Lazy load Incline
    event = "VeryLazy",
  },
}
