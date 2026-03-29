local M = {}

local function in_insert_like_mode()
  local mode = vim.api.nvim_get_mode().mode
  local prefix = mode:sub(1, 1)
  return prefix == "i" or prefix == "t"
end

local function current_explorer()
  local explorers = Snacks.picker.get({ source = "explorer" })
  return explorers[1]
end

local function open_impl()
  local explorer = current_explorer()
  if explorer then
    explorer:focus("list")
    return
  end
  Snacks.explorer()
end

local function toggle_impl()
  local explorer = current_explorer()
  if explorer then
    explorer:close()
    return
  end
  open_impl()
end

function M.open_or_focus()
  if in_insert_like_mode() then
    vim.cmd("stopinsert")
    vim.schedule(open_impl)
    return
  end
  open_impl()
end

function M.toggle()
  if in_insert_like_mode() then
    vim.cmd("stopinsert")
    vim.schedule(toggle_impl)
    return
  end
  toggle_impl()
end

return M
