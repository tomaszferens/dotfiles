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
    opts.incremental_selection = opts.incremental_selection or {}
    opts.incremental_selection = {
      enable = false,
      keymaps = {
        node_incremental = "<TAB>",
        node_decremental = "<S-TAB>",
      },
    }

    local ts_utils = require("nvim-treesitter.ts_utils")

    local node_list = {}
    local current_index = nil

    function Start_select()
      node_list = {}
      current_index = nil
      current_index = 1
      vim.cmd("normal! v")
    end

    local function find_expand_node(node)
      local start_row, start_col, end_row, end_col = node:range()
      local parent = node:parent()
      if parent == nil then
        return nil
      end
      local parent_start_row, parent_start_col, parent_end_row, parent_end_col = parent:range()
      if
        start_row == parent_start_row
        and start_col == parent_start_col
        and end_row == parent_end_row
        and end_col == parent_end_col
      then
        return find_expand_node(parent)
      end
      return parent
    end

    function Select_parent_node()
      if current_index == nil then
        return
      end

      local node = node_list[current_index - 1]
      local parent = nil
      if node == nil then
        parent = ts_utils.get_node_at_cursor()
      else
        parent = find_expand_node(node)
      end
      if not parent then
        vim.cmd("normal! gv")
        return
      end

      table.insert(node_list, parent)
      current_index = current_index + 1
      local start_row, start_col, end_row, end_col = parent:range()
      vim.fn.setpos(".", { 0, start_row + 1, start_col + 1, 0 })
      vim.cmd("normal! v")
      vim.fn.setpos(".", { 0, end_row + 1, end_col, 0 })
    end

    function Restore_last_selection()
      if not current_index or current_index <= 1 then
        return
      end

      current_index = current_index - 1
      local node = node_list[current_index]
      local start_row, start_col, end_row, end_col = node:range()
      vim.fn.setpos(".", { 0, start_row + 1, start_col + 1, 0 })
      vim.cmd("normal! v")
      vim.fn.setpos(".", { 0, end_row + 1, end_col, 0 })
    end

    vim.api.nvim_set_keymap("n", "v", ":lua Start_select()<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("v", "<TAB>", ":lua Select_parent_node()<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("v", "<S-TAB>", ":lua Restore_last_selection()<CR>", { noremap = true, silent = true })

    return opts
  end,
}
