local formatter_configs = {
  {
    name = "oxfmt",
    files = {
      ".oxfmtrc.json",
      ".oxfmtrc.jsonc",
      "oxfmt.config.ts",
      "oxfmt.config.mts",
      "oxfmt.config.cts",
      "oxfmt.config.js",
      "oxfmt.config.mjs",
      "oxfmt.config.cjs",
    },
  },
  {
    name = "biome",
    files = { "biome.json", "biome.jsonc" },
  },
  {
    name = "prettierd",
    files = {
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.json5",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      ".prettierrc.ts",
      ".prettierrc.cts",
      ".prettierrc.mts",
      ".prettierrc.toml",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
      "prettier.config.ts",
      "prettier.config.cts",
      "prettier.config.mts",
    },
  },
}

local function package_formatter(file)
  if not vim.uv.fs_stat(file) then
    return nil
  end

  local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  if not ok then
    return nil
  end

  local dependencies =
    vim.tbl_extend("force", package.dependencies or {}, package.devDependencies or {}, package.peerDependencies or {})

  if dependencies.oxfmt then
    return "oxfmt"
  end
  if dependencies["@biomejs/biome"] then
    return "biome"
  end
  if package.prettier or dependencies.prettier or dependencies.prettierd then
    return "prettierd"
  end
end

local function project_formatter(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local dir = vim.fs.dirname(filename)
  local git_root = vim.fs.root(filename, ".git")

  while dir do
    for _, formatter in ipairs(formatter_configs) do
      for _, config_file in ipairs(formatter.files) do
        if vim.uv.fs_stat(vim.fs.joinpath(dir, config_file)) then
          return { formatter.name }
        end
      end
    end

    local formatter = package_formatter(vim.fs.joinpath(dir, "package.json"))
    if formatter then
      return { formatter }
    end

    if dir == git_root then
      break
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return {}
end

return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    for _, filetype in ipairs({
      "javascript",
      "typescript",
      "javascriptreact",
      "typescriptreact",
      "json",
      "jsonc",
      "css",
      "scss",
      "html",
      "yaml",
      "markdown",
      "graphql",
      "vue",
      "svelte",
    }) do
      opts.formatters_by_ft[filetype] = project_formatter
    end
  end,
}
