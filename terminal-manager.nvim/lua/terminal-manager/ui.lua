local M = {}

local NuiSplit = require("nui.split")
local NuiPopup = require("nui.popup")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")

local ns = vim.api.nvim_create_namespace("terminal_manager_ui")

M._sidebar = nil -- NuiSplit instance
M._tabline = nil -- NuiPopup instance for floating terminals
M._tabline_mode = nil -- "popup" | "winbar" | nil
M._tabline_winnr = nil
M._tab_col_ranges = {}

-- ── Highlight groups ─────────────────────────────────────────────────────────

local function get_hl(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

local function ensure_hl()
  local normal = get_hl("Normal")
  local normal_float = get_hl("NormalFloat")
  local float_border = get_hl("FloatBorder")
  local win_separator = get_hl("WinSeparator")

  local chrome_bg = normal_float.bg or normal.bg
  local border_fg = normal.fg or float_border.fg or win_separator.fg or tonumber("D0D0D0", 16)

  vim.api.nvim_set_hl(0, "TerminalManagerActive", { link = "PmenuSel", default = true })
  vim.api.nvim_set_hl(0, "TerminalManagerActiveName", { link = "PmenuSel", default = true })
  vim.api.nvim_set_hl(0, "TerminalManagerName", { link = "Pmenu", default = true })
  vim.api.nvim_set_hl(0, "TerminalManagerTabActive", { link = "PmenuSel", default = true })
  vim.api.nvim_set_hl(0, "TerminalManagerTabInactive", { link = "Pmenu", default = true })
  vim.api.nvim_set_hl(0, "TerminalManagerChrome", { bg = chrome_bg })
  vim.api.nvim_set_hl(0, "TerminalManagerTabSep", { fg = border_fg, bg = chrome_bg })
  vim.api.nvim_set_hl(0, "TerminalManagerBorder", { fg = border_fg, bg = chrome_bg })
end

-- ── Sidebar ───────────────────────────────────────────────────────────────────

local function setup_sidebar_keymaps(bufnr)
  local function select()
    if not (M._sidebar and vim.api.nvim_win_is_valid(M._sidebar.winid)) then return end
    local row = vim.api.nvim_win_get_cursor(M._sidebar.winid)[1]
    require("terminal-manager").goto_index(row)
  end
  vim.keymap.set("n", "<CR>", select, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<LeftRelease>", select, { noremap = true, silent = true, buffer = bufnr })
end

---Open the session-picker sidebar to the left of `term_winnr`.
---If the sidebar is already visible, refreshes its content instead.
---Entries are mouse- and `<CR>`-clickable to switch sessions.
---@param term_winnr integer Window id of the active terminal window
function M.show_sidebar(term_winnr)
  if M._sidebar and vim.api.nvim_win_is_valid(M._sidebar.winid) then
    M.refresh_sidebar()
    return
  end

  ensure_hl()
  local config = require("terminal-manager.config")
  local width = (config.options and config.options.sidebar_width) or 25

  -- Mount the split relative to the terminal window
  local caller_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(term_winnr)

  M._sidebar = NuiSplit({
    relative = "win",
    position = "left",
    size = width,
    enter = false,
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      wrap = false,
      cursorline = true,
      winfixwidth = true,
    },
    buf_options = {
      buftype = "nofile",
      bufhidden = "hide",
      swapfile = false,
    },
  })
  M._sidebar:mount()

  setup_sidebar_keymaps(M._sidebar.bufnr)

  local target = vim.api.nvim_win_is_valid(caller_win) and caller_win or term_winnr
  vim.api.nvim_set_current_win(target)

  M.refresh_sidebar()
end

---Close the sidebar window. No-op if the sidebar is not currently visible.
function M.hide_sidebar()
  if M._sidebar then
    if vim.api.nvim_win_is_valid(M._sidebar.winid) then
      M._sidebar:unmount()
    end
    M._sidebar = nil
  end
end

---Redraw the sidebar with the current session list, highlighting the active
---session and repositioning the cursor to its line.
function M.refresh_sidebar()
  if not (M._sidebar and vim.api.nvim_win_is_valid(M._sidebar.winid)) then return end

  local state = require("terminal-manager.state")
  local bufnr = M._sidebar.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local active_line = nil
  for i, term in ipairs(state._terms) do
    local is_active = term.id == state.active_id
    local line = NuiLine()
    if is_active then
      line:append(NuiText("   " .. term.name, "TerminalManagerActive"))
      active_line = i
    else
      line:append(NuiText("   " .. term.name, "TerminalManagerName"))
    end
    line:render(bufnr, ns, i)
  end

  -- Trim any extra lines left from a previous larger list
  local lcount = vim.api.nvim_buf_line_count(bufnr)
  if lcount > #state._terms then
    vim.api.nvim_buf_set_lines(bufnr, #state._terms, -1, false, {})
  end

  vim.bo[bufnr].modifiable = false

  if active_line and vim.api.nvim_win_is_valid(M._sidebar.winid) then
    if vim.api.nvim_get_current_win() ~= M._sidebar.winid then
      vim.api.nvim_win_set_cursor(M._sidebar.winid, { active_line, 0 })
    end
  end
end

-- ── Tabline ───────────────────────────────────────────────────────────────────

local function setup_tabline_keymaps(bufnr)
  local function click_tab()
    if not (M._tabline and vim.api.nvim_win_is_valid(M._tabline.winid)) then return end

    local state = require("terminal-manager.state")
    if #state._terms < 2 then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(M._tabline.winid)
    local row = cursor[1]
    local col = cursor[2]
    if row ~= 2 then
      return
    end

    for _, range in ipairs(M._tab_col_ranges) do
      if col >= range.col_start and col <= range.col_end then
        require("terminal-manager").goto_index(range.index)
        return
      end
    end
  end
  vim.keymap.set("n", "<CR>", click_tab, { noremap = true, silent = true, buffer = bufnr })
  vim.keymap.set("n", "<LeftRelease>", click_tab, { noremap = true, silent = true, buffer = bufnr })
end

local function escape_statusline(text)
  return (text or ""):gsub("%%", "%%%%")
end

local function clear_term_winbars()
  local state = require("terminal-manager.state")
  for _, term in ipairs(state._terms) do
    if term.winnr and vim.api.nvim_win_is_valid(term.winnr) then
      vim.wo[term.winnr].winbar = ""
    end
  end
end

local function hide_popup_tabline()
  if M._tabline then
    if vim.api.nvim_win_is_valid(M._tabline.winid) then
      M._tabline:unmount()
    end
    M._tabline = nil
  end
end

local function tabline_uses_winbar(term_winnr)
  if not vim.api.nvim_win_is_valid(term_winnr) then
    return false
  end
  local wincfg = vim.api.nvim_win_get_config(term_winnr)
  return not (wincfg.relative and wincfg.relative ~= "")
end

local function render_winbar(term_winnr)
  if not vim.api.nvim_win_is_valid(term_winnr) then
    return
  end

  local state = require("terminal-manager.state")
  if #state._terms == 0 then
    vim.wo[term_winnr].winbar = ""
    return
  end

  local parts = { "%#TerminalManagerChrome# " }
  for i, term in ipairs(state._terms) do
    local is_active = term.id == state.active_id
    local hl = is_active and "TerminalManagerTabActive" or "TerminalManagerTabInactive"
    parts[#parts + 1] = string.format("%%#%s# %s ", hl, escape_statusline(term.name))
    if i < #state._terms then
      parts[#parts + 1] = "%#TerminalManagerTabSep#│"
    end
  end
  parts[#parts + 1] = "%#TerminalManagerChrome#%="

  vim.wo[term_winnr].winbar = table.concat(parts)
end

local function chrome_height()
  local state = require("terminal-manager.state")
  return #state._terms >= 2 and 2 or 1
end

local function tabline_window_config(term_winnr)
  local height = chrome_height()
  local wincfg = vim.api.nvim_win_get_config(term_winnr)
  local config = require("terminal-manager.config")
  local width = wincfg.width
  if config.options.display_mode == "float" and (config.options.border or "rounded") ~= "none" then
    width = width + 2
  end

  return {
    relative = "editor",
    row = math.max(0, wincfg.row - height),
    col = wincfg.col,
    width = width,
    height = height,
    zindex = (wincfg.zindex or config.options.zindex or 250) + 1,
  }
end

---Show tabs for the terminal window `term_winnr`.
---Split windows use a real `winbar`; floating terminals use a floating popup.
---@param term_winnr integer Window id of the active terminal window
function M.show_tabline(term_winnr)
  if not vim.api.nvim_win_is_valid(term_winnr) then
    return
  end

  ensure_hl()

  if tabline_uses_winbar(term_winnr) then
    hide_popup_tabline()
    M._tabline_mode = "winbar"
    M._tabline_winnr = term_winnr
    M.refresh_tabline()
    return
  end

  clear_term_winbars()
  M._tabline_mode = "popup"
  M._tabline_winnr = term_winnr

  local popup_cfg = tabline_window_config(term_winnr)

  if M._tabline and vim.api.nvim_win_is_valid(M._tabline.winid) then
    vim.api.nvim_win_set_config(M._tabline.winid, popup_cfg)
    M.refresh_tabline()
    return
  end

  M._tabline = NuiPopup({
    relative = popup_cfg.relative,
    position = { row = popup_cfg.row, col = popup_cfg.col },
    size = { width = popup_cfg.width, height = popup_cfg.height },
    border = { style = "none" },
    zindex = popup_cfg.zindex,
    enter = false,
    focusable = true,
    buf_options = {
      buftype = "nofile",
      bufhidden = "hide",
      swapfile = false,
    },
    win_options = {
      winblend = 0,
      winhighlight = "Normal:TerminalManagerChrome,NormalFloat:TerminalManagerChrome,FloatBorder:TerminalManagerBorder",
    },
  })
  M._tabline:mount()

  setup_tabline_keymaps(M._tabline.bufnr)
  M.refresh_tabline()
end

---Hide the terminal tabs.
function M.hide_tabline()
  hide_popup_tabline()
  clear_term_winbars()
  M._tabline_mode = nil
  M._tabline_winnr = nil
  M._tab_col_ranges = {}
end

---Redraw the tab UI with session labels, highlighting the active tab.
function M.refresh_tabline()
  if M._tabline_mode == "winbar" then
    if not (M._tabline_winnr and vim.api.nvim_win_is_valid(M._tabline_winnr)) then
      return
    end
    clear_term_winbars()
    render_winbar(M._tabline_winnr)
    return
  end

  if not (M._tabline and vim.api.nvim_win_is_valid(M._tabline.winid)) then return end

  local state = require("terminal-manager.state")
  local bufnr = M._tabline.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local width = vim.api.nvim_win_get_width(M._tabline.winid)
  local border_line = NuiLine()
  M._tab_col_ranges = {}

  border_line:append(NuiText(string.rep("─", math.max(1, width)), "TerminalManagerBorder"))

  if #state._terms < 2 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })
    border_line:render(bufnr, ns, 1)
    vim.bo[bufnr].modifiable = false
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "" })
  border_line:render(bufnr, ns, 1)

  local line = NuiLine()
  local col = 0
  line:append(NuiText(" ", "TerminalManagerChrome"))
  col = 1

  for i, term in ipairs(state._terms) do
    local is_active = term.id == state.active_id
    local label = " " .. term.name .. " "
    local sep = (i < #state._terms) and "│" or ""

    table.insert(M._tab_col_ranges, {
      index = i,
      col_start = col,
      col_end = col + #label - 1,
    })
    col = col + #label + #sep

    line:append(NuiText(label, is_active and "TerminalManagerTabActive" or "TerminalManagerTabInactive"))
    if sep ~= "" then
      line:append(NuiText(sep, "TerminalManagerTabSep"))
    end
  end

  if col < width then
    line:append(NuiText(string.rep(" ", width - col), "TerminalManagerChrome"))
  end

  line:render(bufnr, ns, 2)
  vim.bo[bufnr].modifiable = false
end

---Update the tab UI after the terminal window has been resized or moved.
---@param term_winnr integer Window id of the active terminal window
function M.reposition_tabline(term_winnr)
  if M._tabline_mode == "winbar" then
    if vim.api.nvim_win_is_valid(term_winnr) then
      M._tabline_winnr = term_winnr
      M.refresh_tabline()
    end
    return
  end

  if not (M._tabline and vim.api.nvim_win_is_valid(M._tabline.winid)) then return end
  if not vim.api.nvim_win_is_valid(term_winnr) then return end

  local popup_cfg = tabline_window_config(term_winnr)

  vim.api.nvim_win_set_config(M._tabline.winid, popup_cfg)
end

---Refresh whichever UI elements are currently visible (sidebar and/or tabline).
function M.refresh()
  M.refresh_sidebar()
  M.refresh_tabline()
end

return M
