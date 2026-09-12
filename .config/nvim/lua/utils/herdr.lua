--- Herdr (herdr.dev) bridge: send @file references from Neovim to coding
--- agents in the same herdr workspace, and answer reference queries from the
--- alt+a bridge script (~/.config/herdr/nvim-ai-bridge.sh), which reaches
--- this instance over the workspace-scoped server socket started in
--- config/options.lua. Everything is scoped to HERDR_WORKSPACE_ID so
--- parallel checkouts never cross.
local M = {}

local HERDR = vim.fn.exepath("herdr")

---@type nil|fun(): boolean
M.codediff_option_a_handler = nil

function M.available()
  return HERDR ~= "" and vim.env.HERDR_WORKSPACE_ID ~= nil
end

---@param args string[]
---@return table|nil result field of the CLI's JSON response
local function herdr_json(args)
  local cmd = { HERDR }
  vim.list_extend(cmd, args)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 or not output or output:match("^%s*$") then
    return nil
  end

  local ok, decoded = pcall(vim.fn.json_decode, output)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  return decoded.result
end

--- Path of the current buffer, relative to Neovim's cwd. One checkout per
--- herdr workspace and agents start in the checkout root, so a cwd-relative
--- reference stays unambiguous; files outside the cwd keep their absolute
--- path. CodeDiff virtual buffers resolve to their repo-relative path via
--- utils.ai.strip_cwd.
local function buffer_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end

  if not name:match("^%a[%w+.-]*://") then
    name = vim.fn.fnamemodify(name, ":p")
  end

  local path = require("utils.ai").strip_cwd(name)
  if path == "" then
    return nil
  end

  return path
end

--- "@/abs/path", or "@/abs/path#L<start>[-<end>]" in visual mode. Herdr
--- delivers alt+a via --remote-expr rather than a real keypress, so visual
--- mode is still active here: read the live anchor/cursor lines ('< and '>
--- are stale until visual mode exits), then leave visual mode to match the
--- old <M-a> behavior.
local function current_reference()
  local file = buffer_path()
  if not file then
    return nil
  end

  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return "@" .. file
  end

  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "n", false)

  if start_line == end_line then
    return "@" .. file .. "#L" .. start_line
  end

  return "@" .. file .. "#L" .. start_line .. "-" .. end_line
end

local function workspace_agents()
  local result = herdr_json({ "agent", "list" })
  local agents = {}
  for _, agent in ipairs(result and result.agents or {}) do
    if agent.workspace_id == vim.env.HERDR_WORKSPACE_ID then
      table.insert(agents, agent)
    end
  end

  return agents
end

---@return table<string, table> tab_id -> tab info ({ number, label, ... })
local function workspace_tabs()
  local result = herdr_json({ "tab", "list", "--workspace", vim.env.HERDR_WORKSPACE_ID })
  local tabs = {}
  for _, tab in ipairs(result and result.tabs or {}) do
    tabs[tab.tab_id] = tab
  end

  return tabs
end

local function agent_label(agent, tab)
  return string.format(
    "%s · %s · %s · [%s]",
    tab and tab.number or "?",
    tab and tab.label or "?",
    agent.name or agent.display_agent or agent.agent or "agent",
    agent.agent_status or "unknown"
  )
end

--- Insert text into an agent pane's input box without submitting.
local function send_to_pane(pane_id, text)
  vim.system({ HERDR, "pane", "send-text", pane_id, text }, {}, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify("herdr send-text failed: " .. (result.stderr or ""), vim.log.levels.WARN)
      end)
    end
  end)
end

--- Send text to a coding-agent pane in the current herdr workspace. Exactly
--- one agent: send immediately. Several: picker sorted by tab order.
---@param text string
---@return boolean
function M.send(text)
  local agents = workspace_agents()
  if #agents == 0 then
    vim.notify("No herdr agent in this workspace", vim.log.levels.WARN)
    return false
  end

  if #agents == 1 then
    send_to_pane(agents[1].pane_id, text)
    return true
  end

  local tabs = workspace_tabs()
  table.sort(agents, function(a, b)
    local a_number = tabs[a.tab_id] and tabs[a.tab_id].number or math.huge
    local b_number = tabs[b.tab_id] and tabs[b.tab_id].number or math.huge
    if a_number ~= b_number then
      return a_number < b_number
    end
    return (a.pane_id or "") < (b.pane_id or "")
  end)

  vim.ui.select(agents, {
    prompt = "Send to agent",
    format_item = function(agent)
      return agent_label(agent, tabs[agent.tab_id])
    end,
  }, function(agent)
    if agent then
      send_to_pane(agent.pane_id, text)
    end
  end)

  return true
end

--- alt+a while Neovim is focused (invoked over --remote-expr by the bridge
--- script, and by the native <M-a> mapping should the key ever reach Neovim
--- directly). The reference is built synchronously because it is
--- mode-sensitive; the herdr CLI calls and picker are deferred so the
--- blocking --remote-expr round-trip returns immediately.
function M.send_current_reference()
  if M.codediff_option_a_handler and M.codediff_option_a_handler() then
    return ""
  end

  local reference = current_reference()
  vim.schedule(function()
    if reference then
      M.send(reference .. " ")
    else
      vim.notify("No file in current buffer", vim.log.levels.WARN)
    end
  end)

  return ""
end

--- <M-b> equivalent: ask for a prompt to wrap around the reference first.
function M.send_current_reference_with_prompt()
  local reference = current_reference()
  vim.schedule(function()
    if not reference then
      vim.notify("No file in current buffer", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = reference .. " - " }, function(input)
      if input == nil then
        return
      end

      if input == "" then
        M.send(reference .. " ")
      else
        M.send(reference .. " - " .. input)
      end
    end)
  end)

  return ""
end

--- alt+a while an agent pane is focused: the bridge script asks for the open
--- file here and inserts it into the focused pane itself.
function M.file_reference()
  local file = buffer_path()
  return file and ("@" .. file) or ""
end

return M
