local M = {}

local function in_insert_like_mode()
  local mode = vim.api.nvim_get_mode().mode
  local prefix = mode:sub(1, 1)
  return prefix == "i" or prefix == "t"
end

local function is_terminal_manager_win(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end

  local ok, state = pcall(require, "terminal-manager.state")
  if not ok then
    return false
  end

  return state.get_by_bufnr(vim.api.nvim_win_get_buf(win)) ~= nil
end

local function has_visible_terminal()
  local ok, state = pcall(require, "terminal-manager.state")
  if not ok then
    return false
  end

  for _, term in ipairs(state._terms) do
    if term.winnr and vim.api.nvim_win_is_valid(term.winnr) then
      return true
    end
  end

  return false
end

local function is_anchor_candidate(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end

  if vim.api.nvim_win_get_tabpage(win) ~= vim.api.nvim_get_current_tabpage() then
    return false
  end

  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end

  if is_terminal_manager_win(win) then
    return false
  end

  return true
end

local function anchor_window()
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  if is_anchor_candidate(previous) then
    return previous
  end

  local current = vim.api.nvim_get_current_win()
  if is_anchor_candidate(current) then
    return current
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_anchor_candidate(win) then
      return win
    end
  end
end

local function dock_explorer_above_terminal(picker, anchor)
  if not picker or not is_anchor_candidate(anchor) then
    return false
  end

  local root = picker.layout and picker.layout.root and picker.layout.root.win
  if not (root and vim.api.nvim_win_is_valid(root)) then
    return false
  end

  local width = vim.api.nvim_win_get_width(root)
  local ok, ret = pcall(vim.fn.win_splitmove, root, anchor, { vertical = true, rightbelow = false })
  if not ok or ret ~= 0 then
    return false
  end

  if vim.api.nvim_win_is_valid(root) then
    pcall(vim.api.nvim_win_set_width, root, width)
  end

  return true
end

local function current_explorer()
  local explorers = Snacks.picker.get({ source = "explorer" })
  return explorers[1]
end

local function ensure_terminal_layout_later()
  local ok, terminal = pcall(require, "terminal-manager.terminal")
  if not ok then
    return
  end

  local attempts = 0
  local function ensure_later()
    attempts = attempts + 1
    if terminal.ensure_horizontal_layout() or attempts >= 20 then
      return
    end
    vim.defer_fn(ensure_later, 20)
  end

  ensure_later()
end

local function open_impl()
  local terminal_visible = has_visible_terminal()
  local anchor = terminal_visible and anchor_window() or nil

  local explorer = current_explorer()
  if explorer then
    if anchor then
      dock_explorer_above_terminal(explorer, anchor)
    end
    ensure_terminal_layout_later()
    explorer:focus("list")
    return
  end

  if not terminal_visible or not anchor then
    Snacks.explorer()
    ensure_terminal_layout_later()
    return
  end

  local current = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(anchor)

  local ok, picker_or_err = pcall(Snacks.explorer)
  if not ok then
    if vim.api.nvim_win_is_valid(current) then
      vim.api.nvim_set_current_win(current)
    end
    vim.notify(("Failed to open Snacks explorer: %s"):format(picker_or_err), vim.log.levels.ERROR)
    return
  end

  local attempts = 0
  local function dock_later()
    attempts = attempts + 1
    if dock_explorer_above_terminal(picker_or_err, anchor) or attempts >= 20 then
      ensure_terminal_layout_later()
      return
    end
    vim.defer_fn(dock_later, 20)
  end

  dock_later()
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
