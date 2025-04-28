local ts_format_eslint_prettier = {
  "prettierd",
  lsp_format = "last",
}

local per_project_formatters = {
  miranda = {
    typescript = ts_format_eslint_prettier,
    typescriptreact = ts_format_eslint_prettier,
  },
  vinny = {
    typescript = ts_format_eslint_prettier,
    typescriptreact = ts_format_eslint_prettier,
  },
}

function get_project_formatter()
  local cwd = vim.fn.getcwd()
  local project = cwd:match("([^/]+)$")

  local config = per_project_formatters[project]
  return config or {}
end

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = get_project_formatter(),
  },
}
