local M = {}

local state = require("terminal-manager.state")
local config = require("terminal-manager.config")
local terminal = require("terminal-manager.terminal")
local ui = require("terminal-manager.ui")

local auto_rename_timer = nil

-- Return a display name from b:term_title, or nil if the shell is idle
-- (idle = title is just the shell binary or a "user@host: path" prompt).
local function process_name_from_title(title)
  if not title or title == "" then return nil end
  local shell_base = vim.fn.fnamemodify(config.options.shell, ":t")
  -- Strip leading dash (login shell indicator like "-zsh")
  local clean = title:match("^%-(.+)$") or title
  -- Compare basename of title against the configured shell
  local title_base = clean:match("([^/]+)$") or clean
  if title_base == shell_base then return nil end
  -- Idle prompt titles like "user@host: ~/dir" or "user@host:~"
  if clean:match("^%S+@%S+:") then return nil end
  return title
end

---Initialise terminal-manager with user options. Must be called once before any other API.
---@param opts? {shell?:string, size?:integer, close_on_exit?:boolean, start_in_insert?:boolean, sidebar_width?:integer, display_mode?:"horizontal"|"vertical"|"float", border?:string, zindex?:integer, escape_key?:string|false, auto_rename?:boolean, colors?:{bg?:string, fg?:string}}
function M.setup(opts)
  config.setup(opts)

  -- Auto-rename timer: poll b:term_title and update tab names
  if auto_rename_timer then
    auto_rename_timer:stop()
    auto_rename_timer:close()
    auto_rename_timer = nil
  end
  local uv = vim.uv or vim.loop
  auto_rename_timer = uv.new_timer()
  auto_rename_timer:start(2000, 2000, vim.schedule_wrap(function()
    if not config.options.auto_rename then return end
    local changed = false
    for _, term in ipairs(state._terms) do
      if not term.user_renamed and vim.api.nvim_buf_is_valid(term.bufnr) then
        local ok, title = pcall(vim.api.nvim_buf_get_var, term.bufnr, "term_title")
        local proc = ok and process_name_from_title(title) or nil
        local desired = proc or term.default_name
        if desired and desired ~= term.name then
          term.name = desired
          changed = true
        end
      end
    end
    if changed then ui.refresh() end
  end))

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("TerminalManagerResize", { clear = true }),
    callback = function()
      vim.schedule(function()
        terminal.ensure_horizontal_layout()
        terminal.resize()
        local active = state.get_active()
        if active and active.winnr and vim.api.nvim_win_is_valid(active.winnr) then
          ui.reposition_tabline(active.winnr)
        end
        ui.refresh()
      end)
    end,
  })

  -- Reposition the floating tabline when any window is resized internally
  -- (e.g. dragging a split border, <C-w><, <C-w>>). VimResized does NOT
  -- cover these cases because it only fires on editor-level resizes.
  vim.api.nvim_create_autocmd("WinResized", {
    group = vim.api.nvim_create_augroup("TerminalManagerWinResize", { clear = true }),
    callback = function()
      vim.schedule(function()
        terminal.ensure_horizontal_layout()

        local active = state.get_active()
        if active and active.winnr and vim.api.nvim_win_is_valid(active.winnr) then
          ui.reposition_tabline(active.winnr)
        end
        -- Restore sidebar width after layout changes (e.g. explorer open/close)
        if ui._sidebar and vim.api.nvim_win_is_valid(ui._sidebar.winid) then
          local w = (config.options and config.options.sidebar_width) or 22
          vim.api.nvim_win_set_width(ui._sidebar.winid, w)
        end
        ui.refresh()
      end)
    end,
  })
end

-- Returns true if any terminal window is currently visible
local function any_visible()
  for _, term in ipairs(state._terms) do
    if term.winnr and vim.api.nvim_win_is_valid(term.winnr) then
      return true
    end
  end
  return false
end

-- Hide all visible terminal windows
local function hide_all()
  for _, term in ipairs(state._terms) do
    terminal.hide(term.id)
  end
end

local function maybe_show_session_ui(term)
  if not (term and term.winnr and vim.api.nvim_win_is_valid(term.winnr)) then return end

  local mode = config.options.display_mode or "horizontal"

  ui.hide_sidebar()
  if mode == "horizontal" or state.count() >= 2 then
    ui.show_tabline(term.winnr)
  else
    ui.hide_tabline()
  end
end

---Adjust the configured terminal size by signed percentage points.
---Hidden sessions keep the new size and will use it next time they are shown.
---@param delta integer
function M.adjust_size(delta)
  delta = tonumber(delta) or 0
  if delta == 0 then
    return
  end

  local current = tonumber(config.options.size) or config.defaults.size or 70
  local next_size = math.max(5, math.min(95, current + delta))
  if next_size == current then
    return
  end

  config.options.size = next_size
  terminal.resize()

  local active = state.get_active()
  if active and active.winnr and vim.api.nvim_win_is_valid(active.winnr) then
    ui.reposition_tabline(active.winnr)
  end
  ui.refresh()
end

---Cycle the terminal layout between horizontal and vertical.
---If a terminal is currently visible, it is re-opened in the new layout while
---preserving the running shell session.
---@return "horizontal"|"vertical" mode
function M.cycle_layout()
  local current_mode = config.options.display_mode or "horizontal"
  local next_mode = current_mode == "vertical" and "horizontal" or "vertical"
  config.options.display_mode = next_mode

  if not any_visible() then
    return next_mode
  end

  local active = state.get_active()
  local current_win = vim.api.nvim_get_current_win()
  local keep_terminal_focus = active and active.winnr and current_win == active.winnr
  local reopen_id = (active and active.id) or state.active_id or state._terms[1].id

  hide_all()
  ui.hide_sidebar()
  ui.hide_tabline()

  terminal.show(reopen_id)
  maybe_show_session_ui(state.get(reopen_id))

  if not keep_terminal_focus and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_set_current_win(current_win)
  end

  return next_mode
end

---Show the terminal panel (creating one if needed), or hide all visible terminals.
---Restores the last active session when re-opening from a hidden state.
function M.toggle()
  if state.count() == 0 then
    M.new()
    return
  end

  if any_visible() then
    hide_all()
    ui.hide_sidebar()
    ui.hide_tabline()
  else
    local id = state.active_id or state._terms[1].id
    terminal.show(id)
    maybe_show_session_ui(state.get(id))
  end
end

---Create a new terminal session and show the sidebar/tabline when applicable.
---@return table The new session entry from state.
function M.new()
  local term = terminal.create()
  maybe_show_session_ui(term)
  return term
end

---Destroy the currently active terminal session. Automatically switches to
---an adjacent session if one exists, or hides the UI entirely if it was last.
function M.close()
  local active = state.get_active()
  if not active then
    return
  end

  local id = active.id
  local idx = state.index_of(id)
  local next_id = nil
  if state.count() > 1 then
    if idx < state.count() then
      next_id = state._terms[idx + 1].id
    else
      next_id = state._terms[idx - 1].id
    end
  end

  terminal.destroy(id)

  if next_id then
    terminal.show(next_id)
    maybe_show_session_ui(state.get(next_id))
  else
    ui.hide_sidebar()
    ui.hide_tabline()
  end
end

---Switch to the next terminal session in the list (wraps around).
---The current window's buffer is swapped in-place; no new split is opened.
function M.next()
  if state.count() == 0 then
    return
  end

  local idx = state.index_of(state.active_id) or 1
  local next_idx = (idx % state.count()) + 1
  local next_id = state._terms[next_idx].id

  if next_id == state.active_id then
    return
  end

  terminal.swap_to(next_id)
  ui.refresh()
end

---Switch to the previous terminal session in the list (wraps around).
---The current window's buffer is swapped in-place; no new split is opened.
function M.prev()
  if state.count() == 0 then
    return
  end

  local idx = state.index_of(state.active_id) or 1
  local prev_idx = ((idx - 2) % state.count()) + 1
  local prev_id = state._terms[prev_idx].id

  if prev_id == state.active_id then
    return
  end

  terminal.swap_to(prev_id)
  ui.refresh()
end

---Jump directly to the session at 1-based position `n` in the session list.
---If `n` is already the active session and its window is hidden, re-opens it.
---@param n integer 1-based index into the session list
function M.goto_index(n)
  if n < 1 or n > state.count() then
    return
  end
  local term = state._terms[n]
  if term.id == state.active_id then
    if not (term.winnr and vim.api.nvim_win_is_valid(term.winnr)) then
      terminal.show(term.id)
      maybe_show_session_ui(term)
    end
    -- Ensure focus goes to the terminal, not the sidebar
    if term.winnr and vim.api.nvim_win_is_valid(term.winnr) then
      vim.api.nvim_set_current_win(term.winnr)
      if config.options.start_in_insert then
        vim.cmd("startinsert")
      end
    end
    return
  end

  if any_visible() then
    terminal.swap_to(term.id)
  else
    terminal.show(term.id)
    maybe_show_session_ui(state.get(term.id))
  end
  ui.refresh()
end

---Rename the active terminal session.
---If `name` is provided it is applied immediately; otherwise `vim.ui.input` is
---used to prompt the user.
---@param name? string New name for the session
function M.rename(name)
  local active = state.get_active()
  if not active then
    return
  end

  if name and name ~= "" then
    active.name = name
    active.user_renamed = true
    ui.refresh()
  else
    vim.ui.input({ prompt = "Terminal name: ", default = active.name }, function(input)
      if input and input ~= "" then
        active.name = input
        active.user_renamed = true
        ui.refresh()
      end
    end)
  end
end

return M
