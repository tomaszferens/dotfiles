local function get_sub_path(p)
  local cwd = vim.fn.getcwd()
  local file_path = p
  local rest_path = file_path:sub(#cwd + 2) -- +2 to skip the trailing slash
  return rest_path
end

---@param picker_name string
---@param opts? snacks.picker.files.Config|{}
local function start_picker(picker_name, opts)
  ---@type snacks.picker.files.Config|{}
  local defaults = {
    hidden = true,
    ignored = false,
    regex = false,
    cwd = vim.fn.getcwd(),
    cmd = "rg",
  }

  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  return Snacks.picker.pick(picker_name, opts)
end

---@param dir_item snacks.picker.Item
local function grep_in_directory(dir_item)
  local options = {
    pattern = get_sub_path(dir_item.file .. "/"),
  }

  if dir_item.ignored then
    options.ignored = true
  end

  start_picker("live_grep", options)
end

---@param dir_item snacks.picker.Item
local function find_file_in_directory(dir_item)
  local options = {
    pattern = get_sub_path(dir_item.file .. "/"),
  }

  if dir_item.ignored then
    options.ignored = true
  end

  start_picker("files", options)
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          actions = {
            copy_name = function(picker)
              local selected = picker:current()
              local file_name = vim.fn.fnamemodify(selected.file, ":t")

              if selected.type == "file" then
                vim.fn.setreg("+", file_name)
                return
              end

              -- For directories, add trailing slash
              vim.fn.setreg("+", file_name)
            end,
            copy_rel_cwd = function(picker)
              local selected = picker:current()

              if selected.type == "file" then
                vim.fn.setreg("+", get_sub_path(selected.file))
                return
              end

              vim.fn.setreg("+", get_sub_path(selected.file .. "/"))
            end,
            grep_in_directory = function(picker)
              local selected = picker:current()

              if selected.type == "file" then
                grep_in_directory(selected.parent)
                return
              end

              grep_in_directory(selected)
            end,
            find_in_directory = function(picker)
              local selected = picker:current()

              if selected.type == "file" then
                find_file_in_directory(selected.parent)
                return
              end

              find_file_in_directory(selected)
            end,
            code_companion_add = function(picker)
              local explorer_code_companion_add = require("utils.explorer_code_companion_add")
              explorer_code_companion_add(picker)
            end,
          },
        },
      },
      win = {
        list = {
          keys = {
            ["<C-n>"] = false,
            ["<C-y>"] = { "copy_name" },
            ["w"] = { "grep_in_directory" },
            ["f"] = { "find_in_directory" },
            ["<leader>ad"] = { "code_companion_add" },
            ["O"] = { { "pick_win", "jump" }, mode = { "n", "i" } },
            ["T"] = { { "tab" }, mode = { "n", "i" } },
            ["Y"] = { "copy_rel_cwd" },
          },
        },
        input = {
          keys = {
            ["<C-Tab>"] = { { "tab" }, mode = { "n", "i" } },
          },
        },
      },
    },
    scroll = { enabled = false },
  },
  keys = {
    { "<leader>fF", false },
    { "<leader>ff", false },
    { "<C-n>", "<leader>fE", desc = "Explorer Snacks (cwd)", remap = true },
    {
      "<leader>fw",
      function()
        start_picker("live_grep")
      end,
      desc = "Grep (cwd)",
    },
    {
      "<leader>ff",
      function()
        start_picker("files")
      end,
      desc = "Find files (cwd)",
    },
  },
}
