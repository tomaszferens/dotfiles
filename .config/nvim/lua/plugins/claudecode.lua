local function strip_cwd(p)
  local cwd = vim.fn.getcwd()
  local file_path = p

  -- Only process if the path contains the cwd
  if not file_path:find(cwd, 1, true) then
    return file_path
  end

  local rest_path = file_path:sub(#cwd + 2) -- +2 to skip the trailing slash
  return rest_path
end

local function add_to_claude(path)
  local sub_path = strip_cwd(path)
  vim.cmd({ cmd = "ClaudeCodeAdd", args = { sub_path } })
end

return {
  "coder/claudecode.nvim",
  config = true,
  event = "VeryLazy",
  keys = {
    { "<leader>cc", nil, desc = "AI/Claude Code" },
    { "<M-c>", "<cmd>ClaudeCode<cr>", mode = { "n", "i", "t" }, desc = "Toggle Claude" },
    { "<leader>ccr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>ccc", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    {
      "<M-a>",
      function()
        -- Check if we're in a snacks picker (this will be overridden by explorer keybinding when in explorer)
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" or mode == "\22" then
          -- Visual mode (v, V, or ^V)
          vim.cmd("ClaudeCodeSend")
        else
          -- Normal mode - add current file
          local current_file = vim.fn.expand("%:p")
          add_to_claude(current_file)
        end
      end,
      mode = { "n", "v" },
      desc = "Send to Claude",
    },
    {
      "<S-CR>",
      function()
        vim.api.nvim_feedkeys("\\", "n", false)
        vim.defer_fn(function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end, 5)
      end,
      mode = "t",
      desc = "New line in Claude Code",
    },
    {
      "<M-f>",
      function()
        -- Find Claude Code terminal buffer
        local claude_bufnr = nil
        local claude_winnr = nil

        -- Check all buffers for Claude Code terminal
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
            local buf_name = vim.api.nvim_buf_get_name(bufnr)
            if buf_name:match("claude") or buf_name:match("ClaudeCode") then
              claude_bufnr = bufnr
              break
            end
          end
        end

        if claude_bufnr then
          -- Find window with Claude buffer
          for _, winnr in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(winnr) == claude_bufnr then
              claude_winnr = winnr
              break
            end
          end

          if claude_winnr then
            -- Focus the window and enter terminal mode
            vim.api.nvim_set_current_win(claude_winnr)
            vim.cmd("startinsert")
          else
            -- Buffer exists but no window, open it
            vim.cmd("buffer " .. claude_bufnr)
            vim.cmd("startinsert")
          end
        else
          -- No Claude terminal found, create one
          vim.cmd("ClaudeCode")
        end
      end,
      mode = { "n", "i" },
      desc = "Focus Claude Terminal",
    },
    {
      "<M-a>",
      function()
        -- Find first real file buffer that exists on disk and is visible in a window
        for _, winnr in ipairs(vim.api.nvim_list_wins()) do
          local bufnr = vim.api.nvim_win_get_buf(winnr)
          if vim.api.nvim_buf_is_valid(bufnr) then
            local buftype = vim.bo[bufnr].buftype
            local buf_name = vim.api.nvim_buf_get_name(bufnr)

            -- Skip special buffers and check if file exists on disk
            if
              buftype == ""
              and buf_name ~= ""
              and not buf_name:match("^term://")
              and vim.fn.filereadable(buf_name) == 1
            then
              add_to_claude(vim.fn.fnamemodify(buf_name, ":p"))
              return
            end
          end
        end
      end,
      mode = "t",
      desc = "Add file to Claude from terminal",
    },
  },
  opts = {
    terminal = {
      split_width_percentage = 0.50,
    },
  },
}
