local M = {}

local WEZTERM = vim.fn.exepath("wezterm")
local TMUX = vim.fn.exepath("tmux")

local AGENT_PRIORITY = {
  { name = "pi", aliases = { "pi", "π" } },
  { name = "claude", aliases = { "claude" } },
  { name = "codex", aliases = { "codex" } },
  { name = "opencode", aliases = { "opencode" } },
  { name = "opencode2", aliases = { "opencode2" } },
}

local function wezterm_available()
  return WEZTERM and WEZTERM ~= ""
end

local function tmux_binary_available()
  return TMUX and TMUX ~= ""
end

-- tmux commands (list-clients, list-panes, send-keys) work against the default
-- server even when nvim itself is not running inside tmux; only the
-- pane-adjacency and current-session logic needs us to actually be inside.
local function inside_tmux()
  return tmux_binary_available() and vim.env.TMUX and vim.env.TMUX_PANE
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

--- Names and command lines of the processes attached to a pane's tty.
--- Works for both wezterm panes (tty_name from `wezterm cli list`) and tmux
--- panes (tty_name populated from #{pane_tty}).
local function pane_process_text(pane)
  local tty = pane.tty_name or ""
  if tty == "" then
    return ""
  end

  tty = tty:gsub("^/dev/", "")
  local lines = vim.fn.systemlist({ "ps", "-t", tty, "-o", "comm=", "-o", "command=" })
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
    pane_process_text(pane),
  }, " "):lower()
end

--- Priority rank of the coding agent running in this pane, or nil if none.
---@return number|nil
local function pane_agent_rank(pane)
  local text = pane_search_text(pane)

  for rank, agent in ipairs(AGENT_PRIORITY) do
    for _, alias in ipairs(agent.aliases) do
      if has_word(text, alias) then
        return rank
      end
    end
  end

  return nil
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
  if not tmux_binary_available() then
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
    "#{pane_tty}",
    "#{window_active}",
    "#{pane_active}",
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
      tty_name = parts[10] or "",
      window_active = parts[11] == "1",
      pane_active = parts[12] == "1",
    })
  end

  return panes
end

--- tmux sessions whose client is attached inside the current WezTerm window
--- (matched by client tty against the window's pane ttys).
local function same_wezterm_window_tmux_sessions()
  if not tmux_binary_available() or not wezterm_available() then
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

--- Adjacent tmux pane (as a pane table) in the given direction, or nil.
local function get_tmux_pane_in_direction(direction)
  local current_pane = vim.env.TMUX_PANE
  if not current_pane then
    return nil
  end

  local panes = list_tmux_panes()
  local current
  local by_id = {}
  for _, pane in ipairs(panes) do
    by_id[pane.pane_id] = pane
    if pane.pane_id == current_pane then
      current = pane
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

  return candidates[1] and by_id[candidates[1].pane_id] or nil
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

local DIRECTIONS = { "Down", "Right", "Left", "Up" }

--- Adjacent tmux split that is verified to run a coding agent.
local function adjacent_tmux_agent_pane()
  if not inside_tmux() then
    return nil
  end

  for _, direction in ipairs(DIRECTIONS) do
    local pane = get_tmux_pane_in_direction(direction)
    if pane and pane_agent_rank(pane) then
      return pane.pane_id
    end
  end

  return nil
end

--- Adjacent wezterm split that is verified to run a coding agent.
local function adjacent_wezterm_agent_pane()
  if not wezterm_available() then
    return nil
  end

  local by_id = {}
  for _, pane in ipairs(list_wezterm_panes()) do
    by_id[tostring(pane.pane_id or "")] = pane
  end

  for _, direction in ipairs(DIRECTIONS) do
    local pane_id = get_pane_in_direction(direction)
    if pane_id then
      local pane = by_id[tostring(pane_id)]
      if pane and pane_agent_rank(pane) then
        return pane_id
      end
    end
  end

  return nil
end

--- tmux panes worth inspecting: panes of sessions attached inside the current
--- WezTerm window, plus (when nvim runs inside tmux) panes of the current
--- session. Reachable even when nvim itself is outside tmux — agents often
--- live inside a tmux session in another tab, invisible to `wezterm cli list`.
local function tmux_candidate_panes()
  if not tmux_binary_available() then
    return {}
  end

  local seen = {}
  local panes = {}

  local function add(list, allowed_sessions)
    for _, pane in ipairs(list) do
      local pane_id = tostring(pane.pane_id or "")
      local session_ok = not allowed_sessions or allowed_sessions[pane.session_name or ""]
      if pane_id ~= "" and session_ok and not seen[pane_id] then
        seen[pane_id] = true
        table.insert(panes, pane)
      end
    end
  end

  local window_sessions = same_wezterm_window_tmux_sessions()
  if window_sessions then
    add(list_tmux_panes("server"), window_sessions)
  end
  if inside_tmux() then
    add(list_tmux_panes("session"), nil)
  end

  return panes
end

--- Every pane in reach that runs a coding agent, as
--- { kind = "tmux"|"wezterm", pane_id, rank, visible, focused, order } candidates.
local function agent_candidates()
  local candidates = {}

  local function add(kind, pane_id, rank, visible, focused)
    table.insert(candidates, {
      kind = kind,
      pane_id = pane_id,
      rank = rank,
      visible = visible == true,
      focused = focused == true,
      order = #candidates,
    })
  end

  local current_tmux_pane = tostring(vim.env.TMUX_PANE or "")
  for _, pane in ipairs(tmux_candidate_panes()) do
    if tostring(pane.pane_id) ~= current_tmux_pane then
      local rank = pane_agent_rank(pane)
      if rank then
        -- pane_active is per-window; only the visible window's active pane
        -- counts as focused.
        add("tmux", pane.pane_id, rank, pane.window_active, pane.window_active and pane.pane_active)
      end
    end
  end

  local wezterm_panes, current_wezterm_pane = same_wezterm_window_panes()
  for _, pane in ipairs(wezterm_panes) do
    local pane_id = tostring(pane.pane_id or "")
    if pane_id ~= "" and pane_id ~= current_wezterm_pane then
      local rank = pane_agent_rank(pane)
      if rank then
        add("wezterm", tonumber(pane.pane_id), rank, false, false)
      end
    end
  end

  -- The agent the user is looking at wins: panes in the *active* tmux window
  -- beat hidden ones, regardless of agent priority — otherwise pi in window 0
  -- would always steal from claude in the currently selected window. Then the
  -- focused pane within that window, then AGENT_PRIORITY order. On remaining
  -- ties prefer tmux targets: send-keys hits the exact pane, whereas a wezterm
  -- pane hosting tmux only forwards to whatever pane happens to be active.
  table.sort(candidates, function(a, b)
    if a.visible ~= b.visible then
      return a.visible
    end
    if a.focused ~= b.focused then
      return a.focused
    end
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    if a.kind ~= b.kind then
      return a.kind == "tmux"
    end
    return a.order < b.order
  end)

  return candidates
end

--- Pick the pane to send to. Only panes verified to run a coding agent
--- (pi/claude/codex/opencode/opencode2) are considered; adjacent splits win, then the
--- agent in the active tmux window, then the highest-priority agent anywhere
--- in the current window (directly in a wezterm pane or inside a tmux session
--- attached in this window).
local function find_target()
  local tmux_pane = adjacent_tmux_agent_pane()
  if tmux_pane then
    return { kind = "tmux", pane_id = tmux_pane }
  end

  local wezterm_pane = adjacent_wezterm_agent_pane()
  if wezterm_pane then
    return { kind = "wezterm", pane_id = wezterm_pane }
  end

  return agent_candidates()[1]
end

--- Send text to a pane running a coding agent: an adjacent tmux/wezterm split
--- first, otherwise the best agent pane in the current window — including
--- agents running inside tmux sessions in other tabs.
---@param text string
---@return boolean
function M.send(text)
  local target = find_target()
  if not target then
    vim.notify("No coding-agent pane found (pi/claude/codex/opencode/opencode2)", vim.log.levels.WARN)
    return false
  end

  if target.kind == "tmux" then
    return send_to_tmux_pane(target.pane_id, text)
  end

  return send_to_pane(target.pane_id, text)
end

local function strip_codediff_url(p)
  if type(p) ~= "string" then
    return nil
  end

  -- CodeDiff virtual buffers use:
  -- codediff:///<git-root>///<revision>/<repo-relative-path>
  -- For AI references we want only the repo-relative path, not the virtual URI.
  local _root, _revision, rel = p:match("^codediff:///(.-)///([^/]+)/(.+)$")
  return rel
end

function M.strip_cwd(p)
  if type(p) ~= "string" or p == "" then
    return p
  end

  local codediff_rel = strip_codediff_url(p)
  if codediff_rel then
    return codediff_rel
  end

  local cwd = vim.fn.getcwd():gsub("[/\\]$", "")
  local normalized = p:gsub("\\", "/")

  if normalized == cwd then
    return ""
  end

  if normalized:sub(1, #cwd + 1) == cwd .. "/" then
    return normalized:sub(#cwd + 2)
  end

  return p
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

    M.send(reference .. " - " .. input)
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
