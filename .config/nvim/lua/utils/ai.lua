local M = {}

local function get_ergoterm()
  return require("ergoterm")
end

local function get_chats()
  return get_ergoterm().filter_by_tag("ai_chat")
end

local function get_default()
  for _, term in ipairs(get_chats()) do
    if term.name == "claude" then
      return term
    end
  end
  return get_chats()[1]
end

local function get_open_terminal()
  local chats = get_chats()
  for _, term in ipairs(chats) do
    if term:is_open() then
      return term
    end
  end
  if #chats > 0 then
    return chats[1]
  end
  return nil
end

function M.strip_cwd(p)
  local cwd = vim.fn.getcwd()
  if not p:find(cwd, 1, true) then
    return p
  end
  return p:sub(#cwd + 2)
end

function M.toggle(name)
  for _, term in ipairs(get_chats()) do
    if term.name == name then
      term:toggle()
      return
    end
  end
end

function M.send(arg_object)
  local msg = arg_object.msg or ""
  local chats = get_chats()
  local default = get_default()

  if msg == "{file}" then
    local file = M.strip_cwd(vim.fn.expand("%:p"))
    get_ergoterm().select_started({
      terminals = chats,
      prompt = "Add file to chat",
      callbacks = function(term)
        return term:send({ term.meta.add_file(file) }, { new_line = false, trim = false })
      end,
      default = default,
    })
  elseif msg == "{selection}" then
    get_ergoterm().select_started({
      terminals = chats,
      prompt = "Send to chat",
      callbacks = function(term)
        return term:send("visual_selection", { trim = false })
      end,
      default = default,
    })
  else
    get_ergoterm().select_started({
      terminals = chats,
      prompt = "Send to chat",
      callbacks = function(term)
        return term:send({ msg })
      end,
      default = default,
    })
  end
end

function M.send_visual_selection_to_ai_terminals()
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

  M.send({ msg = reference })
end

function M.add_path_to_ai_terminal(path)
  local term = get_open_terminal()
  if not term then
    return
  end
  local stripped = M.strip_cwd(path)
  local msg = term.meta.add_file(stripped)
  term:send({ msg }, { trim = false, new_line = false })
end

function M.focus_terminal()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert")
      return
    end
  end
end

return M
