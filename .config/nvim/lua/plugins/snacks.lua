local function get_sub_path(p)
  local cwd = vim.fn.getcwd()
  local file_path = p

  -- Only process if the path contains the cwd
  if not file_path:find(cwd, 1, true) then
    return file_path
  end

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

  local picker = Snacks.picker.pick(picker_name, opts)

  if picker then
    picker.list.win:on("VimResized", function()
      picker:action("calculate_file_truncate_width")
    end)
  end
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

local function calculate_file_truncate_width(self)
  local width = self.list.win:size().width
  self.opts.formatters.file.truncate = width - 6
end

---@param picker snacks.Picker
local function copy_results_to_clipboard(picker)
  local seen_files = {}
  local file_paths = {}

  local selected_items = picker:selected()
  local all_items = picker:items()

  local items = #selected_items > 0 and selected_items or all_items

  for i, item in ipairs(items) do
    if not seen_files[item.file] then
      seen_files[item.file] = true
      local content = "@" .. get_sub_path(item.file)
      table.insert(file_paths, content)
    end
  end

  local clipboard_content = table.concat(file_paths, "\n")
  vim.fn.setreg("+", clipboard_content)
  picker:close()
  vim.notify("Copied " .. #file_paths .. " file(s) to clipboard", vim.log.levels.INFO, { title = "Snacks" })
end

local picker_actions = {
  calculate_file_truncate_width = calculate_file_truncate_width,
  copy_results_to_clipboard = copy_results_to_clipboard,
}

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        lsp_references = {
          actions = picker_actions,
        },
        grep = {
          actions = picker_actions,
        },
        live_grep = {
          actions = picker_actions,
        },
        files = {
          actions = picker_actions,
        },
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
            code_companion_add_explorer = function(picker)
              local ccMod = require("utils.explorer_code_companion_add")
              ccMod.explorer_code_compaion_add(picker)
            end,
            claudecode_add_explorer = function(picker)
              local selected = picker:current()
              if selected and selected.file then
                vim.cmd("ClaudeCodeAdd " .. selected.file)
              end
            end,
          },
        },
      },
      win = {
        list = {
          on_buf = function(self)
            self:execute("calculate_file_truncate_width")
          end,
          keys = {
            ["<C-n>"] = false,
            ["<C-y>"] = { "copy_name" },
            ["w"] = { "grep_in_directory" },
            ["f"] = { "find_in_directory" },
            ["<leader>ad"] = { "code_companion_add_explorer" },
            ["<leader>cca"] = { "claudecode_add_explorer" },
            ["O"] = { { "pick_win", "jump" }, mode = { "n", "i" } },
            ["T"] = { { "tab" }, mode = { "n", "i" } },
            ["Y"] = { "copy_rel_cwd" },
            ["<M-a>"] = { "copy_results_to_clipboard" },
          },
        },
        input = {
          keys = {
            ["<C-Tab>"] = { { "tab" }, mode = { "n", "i" } },
            ["<M-a>"] = { { "copy_results_to_clipboard" }, mode = { "n", "i" } },
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
