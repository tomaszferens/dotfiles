-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)

vim.api.nvim_create_augroup("JSLogMacro", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = "JSLogMacro",
  pattern = { "javascript", "typescript", "typescriptreact" },
  callback = function()
    vim.fn.setreg("l", "yoconsole.log('" .. esc .. "pa:" .. esc .. "la, " .. esc .. "pl")
  end,
})

local function eslint_fix_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "eslint" })
  if #clients == 0 then
    return
  end

  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = vim.api.nvim_buf_line_count(bufnr), character = 0 },
    },
    context = {
      only = { "source.fixAll.eslint" },
      diagnostics = {},
    },
  }

  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/codeAction", bufnr) then
      local response = client:request_sync("textDocument/codeAction", params, 1000, bufnr)
      for _, action in ipairs((response and response.result) or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
        end

        local command = type(action.command) == "table" and action.command or action
        if command.command then
          client:request_sync("workspace/executeCommand", command, 1000, bufnr)
        end
      end
    end
  end
end

vim.api.nvim_create_augroup("EslintFixAllOnSave", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = "EslintFixAllOnSave",
  callback = function(event)
    eslint_fix_all(event.buf)
  end,
})

-- vim.lsp.enable({
--   "tailwindcss",
-- })
