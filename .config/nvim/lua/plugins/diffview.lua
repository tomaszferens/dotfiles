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
    local hunk_nav = function(direction)
      return function()
        if vim.bo.filetype == "DiffviewFiles" then
          local wins = vim.api.nvim_tabpage_list_wins(0)
          -- Execute in second window (left diff which tracks cursor)
          vim.api.nvim_win_call(wins[2], function()
            vim.cmd("normal! " .. direction)
          end)
        end
      end
    end

    local go_to_file_key_map = {
      "n",
      "gf",
      function()
        local view = require("diffview.lib").get_current_view()
        local path, line

        if vim.bo.filetype == "DiffviewFiles" then
          -- In panel: get file from cursor item
          local item = view.panel:get_item_at_cursor()
          if not item or not item.absolute_path then
            return
          end
          path = item.absolute_path

          local wins = vim.api.nvim_tabpage_list_wins(0)
          local target_win = wins[1]
          if #wins >= 3 then
            -- Check if right diff (wins[3]) is at line 1
            local right_line = vim.api.nvim_win_call(wins[3], function()
              return vim.fn.line(".")
            end)
            target_win = right_line == 1 and wins[2] or wins[3]
          end
          line = vim.api.nvim_win_call(target_win, function()
            return vim.fn.line(".")
          end)
        else
          -- In diff view: get path from current entry
          if not view.cur_entry or not view.cur_entry.path then
            return
          end
          path = view.cur_entry.path
          line = vim.fn.line(".")
        end

        vim.cmd("DiffviewClose")
        vim.cmd(string.format("edit +%d %s", line, vim.fn.fnameescape(path)))
      end,
      { desc = "Open file in previous tab and close current tab" },
    }

    require("diffview").setup({
      keymaps = {
        view = {
          ["<C-g>"] = "<CMD>DiffviewClose<CR>",
          go_to_file_key_map,
        },
        file_panel = {
          ["<C-g>"] = "<CMD>DiffviewClose<CR>",
          go_to_file_key_map,
          { "n", "[h", hunk_nav("[c"), { desc = "Previous hunk" } },
          { "n", "]h", hunk_nav("]c"), { desc = "Next hunk" } },
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
