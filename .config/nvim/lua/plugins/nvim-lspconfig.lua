return {
  {
    "neovim/nvim-lspconfig",
    -- other settings removed for brevity
    opts = {
      inlay_hints = { enabled = false },
      ---@type lspconfig.options
      servers = {
        vtsls = { enabled = false },
        tsgo = {
          cmd = function(dispatchers, config)
            local bin = "tsgo"
            if config and config.root_dir then
              for _, p in ipairs({
                vim.fs.joinpath(config.root_dir, "node_modules/.bin", bin),
                vim.fs.joinpath(config.root_dir, "node_modules/.pnpm/node_modules/.bin", bin),
              }) do
                if vim.fn.executable(p) == 1 then
                  bin = p
                  break
                end
              end
            end
            return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
          end,
        },
        eslint = {
          settings = {
            workingDirectory = { mode = "auto" },
          },
        },
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
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          keys = {
            { "<leader>cc", false },
            { "<leader>ca", false },
            { "<M-n>", false },
          },
        },
      },
    },
  },
}
