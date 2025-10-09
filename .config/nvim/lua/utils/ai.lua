local M = {}

function M.strip_cwd(p)
  local cwd = vim.fn.getcwd()
  local file_path = p

  -- Only process if the path contains the cwd
  if not file_path:find(cwd, 1, true) then
    return file_path
  end

  local rest_path = file_path:sub(#cwd + 2) -- +2 to skip the trailing slash
  return rest_path
end

function M.send_visual_selection_to_ai_terminals()
  -- Exit visual mode to update marks and get correct positions
  vim.cmd([[execute "normal! \<ESC>"]])

  -- Get visual selection range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Get current file path
  local current_file = vim.fn.expand("%:p")
  local sub_path = M.strip_cwd(current_file) .. "#"

  -- Format the reference with line numbers
  local reference
  if start_line == end_line then
    reference = "@" .. sub_path .. "L" .. start_line
  else
    reference = "@" .. sub_path .. "L" .. start_line .. "-" .. end_line
  end

  require("sidekick.cli").send({ msg = reference })
end

function M.add_file_to_ai_terminals(path)
  local stripped = M.strip_cwd(path)
  require("sidekick.cli").send({ msg = "@" .. stripped })
end

return M
