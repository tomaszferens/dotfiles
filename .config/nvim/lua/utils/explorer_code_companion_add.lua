local fmt = string.format
local path = require("plenary.path")

local M = {}

---@param picker snacks.picker.explorer.Node
function M.code_companion_add(node)
  local codecompanion = require("codecompanion")

  local chat = codecompanion.last_chat()

  if not chat then
    codecompanion.chat()
  end

  chat = codecompanion.last_chat()

  if chat and not chat.ui:is_visible() then
    chat.ui:open()
  end

  -- Helper function to process a file
  local function process_file(file_path)
    local relative_path = vim.fn.fnamemodify(file_path, ":.")
    local ft = vim.filetype.match({ filename = relative_path })
    local ok, content = pcall(function()
      return path.new(relative_path):read()
    end)

    if not ok or not content then
      vim.notify("Could not read file: " .. relative_path, vim.log.levels.WARN)
      return
    end

    local description = fmt(
      [[%s %s:

```%s
%s
```]],
      "Here is the content from the file",
      "located at `" .. relative_path .. "`",
      ft or "",
      content
    )

    local id = "<file>" .. relative_path .. "</file>"

    chat:add_message({
      role = "USER",
      content = description or "",
    }, { reference = id, visible = false })

    chat.references:add({
      id = id,
      path = relative_path,
      source = "codecompanion.strategies.chat.slash_commands.file",
    })
  end

  -- Recursively process directories
  local function process_directory(dir_path)
    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
      vim.notify("Could not scan directory: " .. dir_path, vim.log.levels.WARN)
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir_path .. "/" .. name

      -- Skip hidden files and directories
      if name:sub(1, 1) ~= "." then
        if type == "directory" then
          process_directory(full_path)
        elseif type == "file" then
          process_file(full_path)
        end
      end
    end
  end

  -- Check if node is a directory or file and process accordingly
  if node.type == "directory" then
    vim.notify("Processing directory: " .. node.file, vim.log.levels.INFO)
    process_directory(node.file)
    vim.notify("Finished processing directory", vim.log.levels.INFO)
  else
    -- It's a file, use the existing behavior
    process_file(node.file)
  end
end

---@param picker snacks.Picker
function M.explorer_code_compaion_add(picker)
  local node_or_err = picker:current()

  local node = node_or_err

  if not node then
    vim.notify("No node found under cursor", vim.log.levels.WARN)
    return
  end

  if not node.file then
    vim.notify("No valid file or directory selected in explorer", vim.log.levels.WARN)
    return
  end

  M.code_companion_add(node)
end

return M
