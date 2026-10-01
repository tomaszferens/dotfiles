return {
  {
    "nemanjamalesija/ts-expand-hover.nvim",
    lazy = true,
    opts = {
      -- K is mapped below as a tsc-only LSP key, so the plugin's global mapping
      -- stays off and every other language keeps LazyVim's regular hover.
      keymaps = { hover = false },
    },
    config = function(_, opts)
      require("ts_expand_hover").setup(opts)

      -- The float is a markdown buffer, but the plugin leaves conceal off, so the
      -- ```typescript fence lines show up as text. Conceal them the way Neovim's
      -- own hover does and shrink the window by the rows that disappear.
      local float = require("ts_expand_hover.float")
      local show = float.show
      float.show = function(hover, state, ...)
        -- The server's markdown can end in a newline, which would otherwise
        -- render as an empty last row.
        while #hover.lines > 1 and hover.lines[#hover.lines]:match("^%s*$") do
          table.remove(hover.lines)
        end

        show(hover, state, ...)

        local win = state.float_winid
        if not (win and vim.api.nvim_win_is_valid(win)) then
          return
        end

        vim.wo[win].conceallevel = 2
        -- Unlike the built-in hover this float is focused, so the fences have to
        -- stay hidden on the cursor line too.
        vim.wo[win].concealcursor = "nvc"

        -- The plugin parks the cursor on line 1, which is the hidden fence.
        local width, first_visible = 1, nil
        for i, line in ipairs(hover.lines) do
          if not vim.startswith(line, "```") then
            first_visible = first_visible or i
            width = math.max(width, vim.fn.strdisplaywidth(line))
          end
        end
        if first_visible then
          vim.api.nvim_win_set_cursor(win, { first_visible, 0 })
        end

        -- Drop the key-hint footer. The plugin sizes the float to fit it, so the
        -- width is recomputed from the visible content alone.
        local height = vim.api.nvim_win_get_height(win)
        local win_config = vim.api.nvim_win_get_config(win)
        win_config.footer = ""
        win_config.width = math.min(width, require("ts_expand_hover.config").get().float.max_width)
        win_config.height = math.min(height, vim.api.nvim_win_text_height(win, { max_height = height }).all)
        vim.api.nvim_win_set_config(win, win_config)
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsc = {
          -- Without this capability the TypeScript 7 server never reports that a
          -- type can expand further, and `+` in the float does nothing.
          capabilities = { experimental = { hoverVerbosityLevel = true } },
          settings = {
            ["js/ts"] = {
              -- The server cuts hover types at 500 characters by default.
              maximumHoverLength = 5000,
            },
          },
          keys = {
            {
              "K",
              function()
                require("ts_expand_hover").hover()
              end,
              desc = "Hover (expandable)",
            },
          },
        },
      },
    },
  },
}
