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

function M.add_to_claude(path)
  local sub_path = M.strip_cwd(path)
  vim.cmd({ cmd = "ClaudeCodeAdd", args = { sub_path } })
end

function M.add_to_opencode(path)
  local sub_path = M.strip_cwd(path)
  if sub_path:sub(1, 1) == "/" then
    sub_path = sub_path:sub(2)
  end
  local utils = require("utils.util")
  local bufnr = utils.find_terminal_buffer_by_names({ "opencode" })

  if bufnr then
    local job_id = vim.api.nvim_buf_get_var(bufnr, "terminal_job_id")
    if job_id then
      local p = "@" .. sub_path
      vim.fn.chansend(job_id, p)
      -- Only send \r if path is a file, not a directory
      vim.defer_fn(function()
        local is_directory = vim.fn.isdirectory(path)
        if is_directory == 1 then
          vim.fn.chansend(job_id, "\x1b")
          return
        end

        vim.fn.chansend(job_id, "\r")
      end, 400)
    end
  end
end

-- Send visual selection to Claude Code
function M.send_visual_selection_to_claude()
  vim.cmd("ClaudeCodeSend")
end

-- Send visual selection to OpenCode with line references
function M.send_visual_selection_to_opencode()
  local utils = require("utils.util")
  local bufnr = utils.find_terminal_buffer_by_names({ "opencode" })

  if not bufnr then
    return
  end

  local job_id = vim.api.nvim_buf_get_var(bufnr, "terminal_job_id")
  if not job_id then
    return
  end

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

  vim.fn.chansend(job_id, reference)
  vim.defer_fn(function()
    vim.fn.chansend(job_id, "\r")
  end, 400)
end

-- Send visual selection to both terminals
function M.send_visual_selection_to_ai_terminals()
  local utils = require("utils.util")
  local added_to_any = false

  -- Check for Claude Code terminal
  local claude_bufnr = utils.find_terminal_buffer_by_names({ "claude", "ClaudeCode" })
  if claude_bufnr then
    M.send_visual_selection_to_claude()
    added_to_any = true
  end

  -- Check for OpenCode terminal
  local opencode_bufnr = utils.find_terminal_buffer_by_names({ "opencode" })
  if opencode_bufnr then
    M.send_visual_selection_to_opencode()
    added_to_any = true
  end

  if not added_to_any then
    vim.notify("No AI terminal found (Claude Code or OpenCode)", vim.log.levels.WARN)
  end
end

-- Add file to both Claude Code and OpenCode terminals if they exist
function M.add_file_to_ai_terminals(path)
  local utils = require("utils.util")
  local added_to_any = false

  -- Check for Claude Code terminal
  local claude_bufnr = utils.find_terminal_buffer_by_names({ "claude", "ClaudeCode" })
  if claude_bufnr then
    M.add_to_claude(path)
    added_to_any = true
  end

  -- Check for OpenCode terminal
  local opencode_bufnr = utils.find_terminal_buffer_by_names({ "opencode" })
  if opencode_bufnr then
    M.add_to_opencode(path)
    added_to_any = true
  end

  if not added_to_any then
    vim.notify("No AI terminal found (Claude Code or OpenCode)", vim.log.levels.WARN)
  end
end

return M
