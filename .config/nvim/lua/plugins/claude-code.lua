local function wait_for_claude_code_ready(callback, timeout)
  timeout = timeout or 5000 -- Default 5 second timeout
  local start_time = vim.loop.now()

  local function check_ready()
    local windows = vim.api.nvim_list_wins()

    for _, win in ipairs(windows) do
      local buf = vim.api.nvim_win_get_buf(win)
      local buf_name = vim.api.nvim_buf_get_name(buf)

      if buf_name:find("/claude%-code%-%-") then
        -- Get buffer content
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local content = table.concat(lines, "\n")

        -- Check if "Welcome to Claude Code" exists
        if content:find("Welcome to Claude Code") then
          callback()
          return
        end
      end
    end

    -- Check timeout
    if vim.loop.now() - start_time > timeout then
      vim.notify("Claude Code readiness check timed out", vim.log.levels.WARN)
      callback() -- Call anyway after timeout
      return
    end

    -- Schedule next check in 100ms
    vim.defer_fn(check_ready, 100)
  end

  check_ready()
end

local function is_claude_code_window_open()
  local windows = vim.api.nvim_list_wins()

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)

    if buf_name:find("/claude%-code%-%-") then
      return true
    end
  end

  return false
end

local function focus_claude_code_window(text)
  text = text or ""
  local windows = vim.api.nvim_list_wins()

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)

    -- More specific pattern matching for your example
    if buf_name:find("/claude%-code%-%-") then
      vim.api.nvim_set_current_win(win)

      if text ~= "" then
        -- For terminal mode, we need to use different approach
        -- Send the text directly to the terminal
        vim.api.nvim_chan_send(vim.api.nvim_buf_get_option(buf, "channel"), text)
      end

      return true
    end
  end

  return false
end

return {
  "greggh/claude-code.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for git operations
  },
  config = function()
    require("claude-code").setup({
      window = {
        split_ratio = 0.5,
        position = "vertical",
      },
    })

    local map = LazyVim.safe_keymap_set
    -- this should be a command instead:

    map("n", "<leader>cct", ":ClaudeCode<CR>", { desc = "Toggle Claude Code" })
    map("n", "<leader>ccc", ":ClaudeCodeContinue<CR>", { desc = "Continue Claude Code" })
    map("n", "<leader>ccr", ":ClaudeCodeResume<CR>", { desc = "Resume Claude Code" })
    map("n", "<leader>ccf", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      vim.cmd("ClaudeCode")
      wait_for_claude_code_ready(function()
        vim.api.nvim_feedkeys(
          "I'm currently looking at this buffer: " .. "@" .. relative_buffer_path .. "\n",
          "n",
          true
        )
      end)
    end, { desc = "Open Claude Code with file context" })
    map({ "n", "v" }, "<leader>cca", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      local mode = vim.fn.mode()

      local start_line, end_line
      if mode == "v" or mode == "V" then
        start_line = vim.fn.line(".")
        end_line = vim.fn.line("v")
        -- Ensure start_line <= end_line
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end
      end

      local function add_to_claude_code()
        if mode == "v" or mode == "V" then
          -- Visual mode: get selected lines
          local text = "@" .. relative_buffer_path .. "#" .. start_line .. "-" .. end_line .. "\n"

          -- Exit visual mode first
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

          focus_claude_code_window(text)
        else
          -- Normal mode: just add the file reference
          focus_claude_code_window("@" .. relative_buffer_path .. "\n")
        end
      end

      -- Check if claude-code window exists, if not open it first
      if not is_claude_code_window_open() then
        vim.cmd("ClaudeCode")
        wait_for_claude_code_ready(add_to_claude_code)
      else
        add_to_claude_code()
      end
    end, { desc = "Add file or selection to Claude Code" })
  end,
}
