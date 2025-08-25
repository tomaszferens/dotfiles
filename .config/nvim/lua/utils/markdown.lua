local M = {}

function M.insert_fence()
  -- 1) figure out where we are
  local win = 0
  local buf = 0
  local row = vim.api.nvim_win_get_cursor(win)[1]

  -- 2) insert the three lines
  vim.api.nvim_buf_set_lines(buf, row, row, false, {
    "```",
    "",
    "```",
  })

  -- 3) move cursor to the blank line
  vim.api.nvim_win_set_cursor(win, { row + 2, 0 })

  vim.cmd("startinsert")
end

return M