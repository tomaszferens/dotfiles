return {
  {
    "neovim/nvim-lspconfig",
    -- other settings removed for brevity
    opts = {
      inlay_hints = { enabled = false },
      ---@type lspconfig.options
      servers = {
        eslint = {
          settings = {
            workingDirectory = { mode = "auto" },
          },
        },
      },
      setup = {
        vtsls = function()
          require("lazyvim.util").lsp.on_attach(function(client)
            if client.name == "vtsls" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local on_publish_diagnostics = vim.lsp.diagnostic.on_publish_diagnostics
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        handlers = {
          ["textDocument/publishDiagnostics"] = function(err, res, ...)
            local file_name = vim.fn.fnamemodify(vim.uri_to_fname(res.uri), ":t")
            if string.match(file_name, "^%.env") == nil then
              return on_publish_diagnostics(err, res, ...)
            end
          end,
        },
      })
    end,
  },
}
