-- The lazyvim.plugins.extras.lang.markdown extra wires markdownlint-cli2 into
-- nvim-lint, which floods markdown buffers with MD0xx diagnostics (line length,
-- inline HTML, blank lines around headings, ...). Keep the rest of the extra
-- (marksman, render-markdown, preview) but drop the linter.
return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = nil
      opts.linters_by_ft["markdown.mdx"] = nil
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "markdownlint-cli2"
      end, opts.ensure_installed or {})
    end,
  },
}
