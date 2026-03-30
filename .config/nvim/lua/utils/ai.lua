local M = {}

local WEZTERM = vim.fn.exepath("wezterm")

--- Get the wezterm pane ID in the given direction relative to the current pane.
---@param direction string "Up"|"Down"|"Left"|"Right"
---@return number|nil
local function get_pane_in_direction(direction)
  local wezterm_pane = vim.env.WEZTERM_PANE
  local cmd = { WEZTERM, "cli", "get-pane-direction", direction }
  if wezterm_pane then
    cmd = { WEZTERM, "cli", "get-pane-direction", "--pane-id", wezterm_pane, direction }
  end

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 or not result or result:match("^%s*$") then
    return nil
  end
  local cleaned = result:gsub("%s+", "")
  return tonumber(cleaned)
end

--- Send text to a specific wezterm pane.
---@param pane_id number
---@param text string
local function send_to_pane(pane_id, text)
  vim.fn.system(
    { WEZTERM, "cli", "send-text", "--pane-id", tostring(pane_id), "--no-paste" },
    text
  )
end

--- Send text to the bottom wezterm pane.
---@param text string
function M.send(text)
  local pane_id = get_pane_in_direction("Down")
  if not pane_id then
    vim.notify("No pane below", vim.log.levels.WARN)
    return
  end
  send_to_pane(pane_id, text)
end

function M.strip_cwd(p)
  local cwd = vim.fn.getcwd()
  if not p:find(cwd, 1, true) then
    return p
  end
  return p:sub(#cwd + 2)
end

function M.send_file()
  local file = M.strip_cwd(vim.fn.expand("%:p"))
  M.send("@" .. file .. " ")
end

function M.send_visual_reference()
  vim.cmd([[execute "normal! \<ESC>"]])

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  local current_file = vim.fn.expand("%:p")
  local sub_path = M.strip_cwd(current_file) .. "#"

  local reference
  if start_line == end_line then
    reference = "@" .. sub_path .. "L" .. start_line
  else
    reference = "@" .. sub_path .. "L" .. start_line .. "-" .. end_line
  end

  M.send(reference .. " ")
end

function M.add_path_to_ai_terminal(path)
  local stripped = M.strip_cwd(path)
  M.send("@" .. stripped .. " ")
end

function M.focus_bottom_pane()
  local pane_id = get_pane_in_direction("Down")
  if pane_id then
    vim.fn.system({ WEZTERM, "cli", "activate-pane", "--pane-id", tostring(pane_id) })
  end
end

return M
