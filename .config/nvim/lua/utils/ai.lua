local M = {}

local WEZTERM = vim.fn.exepath("wezterm")

local AGENT_PRIORITY = {
  { name = "pi", aliases = { "pi", "π" } },
  { name = "claude", aliases = { "claude" } },
  { name = "codex", aliases = { "codex" } },
  { name = "opencode", aliases = { "opencode" } },
}

local function wezterm_available()
  return WEZTERM and WEZTERM ~= ""
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

local function pane_matches_agent(pane, agent)
  local title = table.concat({ pane.title or "", pane.tab_title or "" }, " "):lower()

  for _, alias in ipairs(agent.aliases) do
    if has_word(title, alias) then
      return true
    end
  end

  return false
end

--- Find the first tab/pane running a known coding agent, in priority order.
---@return number|nil
local function find_agent_pane()
  local panes = list_wezterm_panes()
  local current_pane = tostring(vim.env.WEZTERM_PANE or "")

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

local function get_target_pane()
  local adjacent_pane = get_pane_in_direction("Down")
    or get_pane_in_direction("Right")
    or get_pane_in_direction("Left")
    or get_pane_in_direction("Up")

  if adjacent_pane then
    return adjacent_pane
  end

  return find_agent_pane()
end

--- Send text to an adjacent wezterm pane (Down, Right, Left, or Up), falling back
--- to the first tab that looks like a coding-agent session.
---@param text string
---@return boolean
function M.send(text)
  local pane_id = get_target_pane()
  if not pane_id then
    vim.notify("No adjacent pane or coding-agent tab", vim.log.levels.WARN)
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
