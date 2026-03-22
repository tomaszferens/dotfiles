local M = {}

local function get_terminal_chan()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      local chan = vim.b[buf].terminal_job_id
      if chan then
        return chan, win, buf
      end
    end
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

function M.send(text)
  local chan = get_terminal_chan()
  if not chan then
    vim.cmd("EssentialTermToggle")
    vim.schedule(function()
      local c = get_terminal_chan()
      if c then
        vim.fn.chansend(c, text)
      end
    end)
    return
  end
  vim.fn.chansend(chan, text)
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

function M.toggle()
  vim.cmd("EssentialTermToggle")
end

return M
