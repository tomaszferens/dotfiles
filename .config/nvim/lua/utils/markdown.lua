local M = {}

function M.insert_fence()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo[buf].buftype == "terminal" then
    local chan = vim.b[buf].terminal_job_id
    if chan then
      vim.fn.chansend(chan, "```\n\n```")
    end
    return
  end

  local win = 0
  local row = vim.api.nvim_win_get_cursor(win)[1]

  vim.api.nvim_buf_set_lines(buf, row, row, false, {
    "```",
    "",
    "```",
  })

  vim.api.nvim_win_set_cursor(win, { row + 2, 0 })
  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

return M