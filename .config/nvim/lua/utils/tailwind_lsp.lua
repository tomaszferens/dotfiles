local M = {}

function M.restart()
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf, name = "tailwindcss" })
  local lspconfig_tailwind = require("lspconfig.configs.tailwindcss")

  -- Get current file's path and detect new root
  local current_file = vim.api.nvim_buf_get_name(buf)
  local new_root = lspconfig_tailwind.default_config.root_dir(current_file)

  -- Check if tailwindcss is not attached to the buffer
  if #clients == 0 then
    vim.cmd("LspStart tailwindcss")
    return
  end

  local client = clients[1]

  if client.config.root_dir == new_root then
    return
  end

  client.stop()

  vim.defer_fn(function()
    vim.cmd("LspStart tailwindcss")
  end, 100)
end

return M
