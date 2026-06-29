return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = vim.tbl_deep_extend("force", opts.inlay_hints or {}, {
        enabled = false,
      })

      opts.servers = opts.servers or {}

      -- TypeScript is selected by vim.g.lazyvim_ts_lsp = "tsgo" in lua/config/options.lua.
      -- Keep eslint-lsp's native singular workingDirectory setting and drop the
      -- VS Code-style plural setting before handing options to nvim-lspconfig.
      opts.servers.eslint = opts.servers.eslint or {}
      opts.servers.eslint.settings = opts.servers.eslint.settings or {}
      opts.servers.eslint.settings.workingDirectory = opts.servers.eslint.settings.workingDirectory or { mode = "auto" }
      opts.servers.eslint.settings.workingDirectories = nil

      opts.servers["*"] = opts.servers["*"] or {}
      opts.servers["*"].keys = opts.servers["*"].keys or {}
      vim.list_extend(opts.servers["*"].keys, {
        { "<leader>cc", false },
        { "<leader>ca", false },
        { "<M-n>", false },
      })

      local on_publish_diagnostics = vim.lsp.diagnostic.on_publish_diagnostics
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        handlers = {
          ["textDocument/publishDiagnostics"] = function(err, res, ...)
            if not res or not res.uri then
              return on_publish_diagnostics(err, res, ...)
            end

            local file_name = vim.fn.fnamemodify(vim.uri_to_fname(res.uri), ":t")
            if not file_name:match("^%.env") then
              return on_publish_diagnostics(err, res, ...)
            end
          end,
        },
      })
    end,
  },
}
