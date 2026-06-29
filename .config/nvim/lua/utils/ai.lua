local M = {}

local WEZTERM = vim.fn.exepath("wezterm")
local TMUX = vim.fn.exepath("tmux")

local AGENT_PRIORITY = {
  { name = "pi", aliases = { "pi", "π" } },
  { name = "claude", aliases = { "claude" } },
  { name = "codex", aliases = { "codex" } },
  { name = "opencode", aliases = { "opencode" } },
}

local function wezterm_available()
  return WEZTERM and WEZTERM ~= ""
end

local function tmux_available()
  return TMUX and TMUX ~= "" and vim.env.TMUX and vim.env.TMUX_PANE
end

--- Get the wezterm pane ID in the given direction relative to the current pane.
---@param direction string "Up"|"Down"|"Left"|"Right"
---@return number|nil
local function get_pane_in_direction(direction)
  if not wezterm_available() then
    return nil
  end

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

local function list_wezterm_panes()
  if not wezterm_available() then
    return {}
  end

  local result = vim.fn.system({ WEZTERM, "cli", "list", "--format", "json" })
  if vim.v.shell_error ~= 0 or not result or result:match("^%s*$") then
    return {}
  end

  local ok, panes = pcall(vim.fn.json_decode, result)
  if not ok or type(panes) ~= "table" then
    return {}
  end

  return panes
end

---@param text string
---@param word string
local function has_word(text, word)
  if word == "π" then
    return text:find(word, 1, true) ~= nil
  end

  return text:match("%f[%w]" .. vim.pesc(word:lower()) .. "%f[%W]") ~= nil
end

local function wezterm_pane_process_text(pane)
  local tty = pane.tty_name or ""
  if tty == "" then
    return ""
  end

  tty = tty:gsub("^/dev/", "")
  local lines = vim.fn.systemlist({ "ps", "-t", tty, "-o", "comm=" })
  if vim.v.shell_error ~= 0 then
    return ""
  end

  return table.concat(lines, " "):lower()
end

local function pane_search_text(pane)
  return table.concat({
    pane.title or "",
    pane.tab_title or "",
    pane.current_command or "",
    pane.window_name or "",
    pane.session_name or "",
    wezterm_pane_process_text(pane),
  }, " "):lower()
end

local function pane_matches_agent(pane, agent)
  local text = pane_search_text(pane)

  for _, alias in ipairs(agent.aliases) do
    if has_word(text, alias) then
      return true
    end
  end

  return false
end

local function pane_is_tmux(pane)
  return has_word(pane_search_text(pane), "tmux")
end

local function current_wezterm_window_id(panes, current_pane)
  if current_pane == "" then
    return nil
  end

  for _, pane in ipairs(panes) do
    if tostring(pane.pane_id or "") == current_pane then
      return pane.window_id
    end
  end

  return nil
end

local function same_wezterm_window_panes()
  local panes = list_wezterm_panes()
  local current_pane = tostring(vim.env.WEZTERM_PANE or "")
  local current_window = current_wezterm_window_id(panes, current_pane)
  if current_window == nil then
    return {}, current_pane, nil
  end

  current_window = tostring(current_window)
  local same_window = {}
  for _, pane in ipairs(panes) do
    if tostring(pane.window_id or "") == current_window then
      table.insert(same_window, pane)
    end
  end

  return same_window, current_pane, current_window
end

--- Find the first tab/pane running a known coding agent in the current WezTerm window.
---@return number|nil
local function find_agent_pane()
  local panes, current_pane = same_wezterm_window_panes()

  for _, agent in ipairs(AGENT_PRIORITY) do
    for _, pane in ipairs(panes) do
      local pane_id = tostring(pane.pane_id or "")
      if pane_id ~= "" and pane_id ~= current_pane and pane_matches_agent(pane, agent) then
        return tonumber(pane.pane_id)
      end
    end
  end

  return nil
end

local function find_tmux_wezterm_pane()
  local panes, current_pane = same_wezterm_window_panes()

  for _, pane in ipairs(panes) do
    local pane_id = tostring(pane.pane_id or "")
    if pane_id ~= "" and pane_id ~= current_pane and pane_is_tmux(pane) then
      return tonumber(pane.pane_id)
    end
  end

  return nil
end

--- Send text to a specific wezterm pane.
---@param pane_id number
---@param text string
---@return boolean
local function send_to_pane(pane_id, text)
  local result = vim.fn.system(
    { WEZTERM, "cli", "send-text", "--pane-id", tostring(pane_id), "--no-paste" },
    text
  )

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to send text to wezterm pane: " .. result, vim.log.levels.WARN)
    return false
  end

  return true
end

local function list_tmux_panes(scope)
  if not tmux_available() then
    return {}
  end

  local format = table.concat({
    "#{pane_id}",
    "#{pane_left}",
    "#{pane_top}",
    "#{pane_width}",
    "#{pane_height}",
    "#{pane_current_command}",
    "#{pane_title}",
    "#{window_name}",
    "#{session_name}",
  }, "\t")
  local cmd
  if scope == "session" then
    cmd = { TMUX, "list-panes", "-s", "-F", format }
  elseif scope == "server" then
    cmd = { TMUX, "list-panes", "-a", "-F", format }
  else
    cmd = { TMUX, "list-panes", "-F", format }
  end
  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local panes = {}
  for _, line in ipairs(lines) do
    local parts = vim.split(line, "\t", { plain = true })
    table.insert(panes, {
      pane_id = parts[1] or "",
      left = tonumber(parts[2]) or 0,
      top = tonumber(parts[3]) or 0,
      width = tonumber(parts[4]) or 0,
      height = tonumber(parts[5]) or 0,
      current_command = parts[6] or "",
      title = parts[7] or "",
      window_name = parts[8] or "",
      session_name = parts[9] or "",
    })
  end

  return panes
end

local function same_wezterm_window_tmux_sessions()
  if not tmux_available() or not wezterm_available() then
    return nil
  end

  local panes = same_wezterm_window_panes()
  if #panes == 0 then
    return nil
  end

  local ttys = {}
  for _, pane in ipairs(panes) do
    local tty = pane.tty_name or ""
    if tty ~= "" then
      ttys[tty] = true
      ttys[tty:gsub("^/dev/", "")] = true
    end
  end

  local lines = vim.fn.systemlist({ TMUX, "list-clients", "-F", "#{client_tty}\t#{session_name}" })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local sessions = {}
  local found = false
  for _, line in ipairs(lines) do
    local parts = vim.split(line, "\t", { plain = true })
    local tty = parts[1] or ""
    local session = parts[2] or ""
    if session ~= "" and (ttys[tty] or ttys[tty:gsub("^/dev/", "")]) then
      sessions[session] = true
      found = true
    end
  end

  return found and sessions or nil
end

local function axis_overlap(a_start, a_end, b_start, b_end)
  return math.max(0, math.min(a_end, b_end) - math.max(a_start, b_start))
end

local function pane_center(pane, axis)
  if axis == "x" then
    return pane.left + pane.width / 2
  end

  return pane.top + pane.height / 2
end

local function get_tmux_pane_in_direction(direction)
  local current_pane = vim.env.TMUX_PANE
  if not current_pane then
    return nil
  end

  local panes = list_tmux_panes()
  local current
  for _, pane in ipairs(panes) do
    if pane.pane_id == current_pane then
      current = pane
      break
    end
  end
  if not current then
    return nil
  end

  local current_right = current.left + current.width
  local current_bottom = current.top + current.height
  local candidates = {}

  for _, pane in ipairs(panes) do
    if pane.pane_id ~= current_pane then
      local right = pane.left + pane.width
      local bottom = pane.top + pane.height
      local distance
      local center_distance
      local overlap

      if direction == "Down" and pane.top >= current_bottom then
        overlap = axis_overlap(current.left, current_right, pane.left, right)
        distance = pane.top - current_bottom
        center_distance = math.abs(pane_center(current, "x") - pane_center(pane, "x"))
      elseif direction == "Up" and bottom <= current.top then
        overlap = axis_overlap(current.left, current_right, pane.left, right)
        distance = current.top - bottom
        center_distance = math.abs(pane_center(current, "x") - pane_center(pane, "x"))
      elseif direction == "Right" and pane.left >= current_right then
        overlap = axis_overlap(current.top, current_bottom, pane.top, bottom)
        distance = pane.left - current_right
        center_distance = math.abs(pane_center(current, "y") - pane_center(pane, "y"))
      elseif direction == "Left" and right <= current.left then
        overlap = axis_overlap(current.top, current_bottom, pane.top, bottom)
        distance = current.left - right
        center_distance = math.abs(pane_center(current, "y") - pane_center(pane, "y"))
      end

      if overlap and overlap > 0 then
        table.insert(candidates, {
          pane_id = pane.pane_id,
          distance = distance or 0,
          center_distance = center_distance or 0,
        })
      end
    end
  end

  table.sort(candidates, function(a, b)
    if a.distance == b.distance then
      return a.center_distance < b.center_distance
    end

    return a.distance < b.distance
  end)

  return candidates[1] and candidates[1].pane_id or nil
end

local function find_tmux_agent_pane()
  local allowed_sessions = same_wezterm_window_tmux_sessions()
  local panes = allowed_sessions and list_tmux_panes("server") or list_tmux_panes("session")
  local current_pane = tostring(vim.env.TMUX_PANE or "")

  for _, agent in ipairs(AGENT_PRIORITY) do
    for _, pane in ipairs(panes) do
      local pane_id = tostring(pane.pane_id or "")
      local session_ok = not allowed_sessions or allowed_sessions[pane.session_name or ""]
      if pane_id ~= "" and pane_id ~= current_pane and session_ok and pane_matches_agent(pane, agent) then
        return pane.pane_id
      end
    end
  end

  return nil
end

local function get_tmux_target_pane()
  if not tmux_available() then
    return nil
  end

  local adjacent_pane = get_tmux_pane_in_direction("Down")
    or get_tmux_pane_in_direction("Right")
    or get_tmux_pane_in_direction("Left")
    or get_tmux_pane_in_direction("Up")

  if adjacent_pane then
    return adjacent_pane
  end

  return find_tmux_agent_pane()
end

local function send_tmux_enter(pane_id)
  local result = vim.fn.system({ TMUX, "send-keys", "-t", pane_id, "Enter" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to send Enter to tmux pane: " .. result, vim.log.levels.WARN)
    return false
  end

  return true
end

local function send_tmux_literal(pane_id, text)
  if text == "" then
    return true
  end

  local result = vim.fn.system({ TMUX, "send-keys", "-t", pane_id, "-l", text })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to send text to tmux pane: " .. result, vim.log.levels.WARN)
    return false
  end

  return true
end

local function send_to_tmux_pane(pane_id, text)
  local remaining = text or ""

  while true do
    local newline = remaining:find("\n", 1, true)
    if not newline then
      return send_tmux_literal(pane_id, remaining)
    end

    if not send_tmux_literal(pane_id, remaining:sub(1, newline - 1)) then
      return false
    end
    if not send_tmux_enter(pane_id) then
      return false
    end

    remaining = remaining:sub(newline + 1)
  end
end

local function send_to_tmux_target(text)
  local pane_id = get_tmux_target_pane()
  if not pane_id then
    return nil
  end

  return send_to_tmux_pane(pane_id, text)
end

local function get_target_pane()
  local adjacent_pane = get_pane_in_direction("Down")
    or get_pane_in_direction("Right")
    or get_pane_in_direction("Left")
    or get_pane_in_direction("Up")

  if adjacent_pane then
    return adjacent_pane
  end

  return find_agent_pane() or find_tmux_wezterm_pane()
end

--- Send text to an adjacent tmux/wezterm pane (Down, Right, Left, or Up), falling back
--- to the first tab/pane that looks like a coding-agent session.
---@param text string
---@return boolean
function M.send(text)
  local tmux_result = send_to_tmux_target(text)
  if tmux_result ~= nil then
    return tmux_result
  end

  local pane_id = get_target_pane()
  if not pane_id then
    vim.notify("No adjacent tmux/wezterm pane or coding-agent tab", vim.log.levels.WARN)
    return false
  end

  return send_to_pane(pane_id, text)
end

function M.strip_cwd(p)
  local cwd = vim.fn.getcwd()
  if not p:find(cwd, 1, true) then
    return p
  end
  return p:sub(#cwd + 2)
end

function M.path_reference(path)
  return "@" .. M.strip_cwd(path)
end

function M.file_reference()
  local file = vim.fn.expand("%:p")
  if file == "" then
    return nil
  end

  return M.path_reference(file)
end

function M.visual_reference()
  vim.cmd([[execute "normal! \<ESC>"]])

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    return nil
  end

  local sub_path = M.strip_cwd(current_file) .. "#"

  if start_line == end_line then
    return "@" .. sub_path .. "L" .. start_line
  end

  return "@" .. sub_path .. "L" .. start_line .. "-" .. end_line
end

function M.send_file()
  local reference = M.file_reference()
  if reference then
    return M.send(reference .. " ")
  end

  return false
end

function M.send_visual_reference()
  local reference = M.visual_reference()
  if reference then
    return M.send(reference .. " ")
  end

  return false
end

function M.prompt_and_send(reference)
  if not reference or reference == "" then
    return false
  end

  vim.ui.input({ prompt = reference .. " - " }, function(input)
    if input == nil then
      return
    end

    if input == "" then
      M.send(reference .. " ")
      return
    end

    M.send(reference .. " - " .. input .. "\n")
  end)

  return true
end

function M.send_file_with_prompt()
  return M.prompt_and_send(M.file_reference())
end

function M.send_visual_reference_with_prompt()
  return M.prompt_and_send(M.visual_reference())
end

function M.add_path_to_ai_terminal(path)
  M.send(M.path_reference(path) .. " ")
end

function M.add_path_to_ai_terminal_with_prompt(path)
  M.prompt_and_send(M.path_reference(path))
end

return M
