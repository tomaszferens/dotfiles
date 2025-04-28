local util = require("utils.util")

local vitestConfigPattern = util.root_pattern("{vite,vitest}.config.{js,ts,mjs,mts}")

local M = {}

M.getVitestConfig = function(path)
  local rootPath = vitestConfigPattern(path)

  if not rootPath then
    return nil
  end

  -- Ordered by config precedence (https://vitest.dev/config/#configuration)
  local possibleVitestConfigNames = {
    "vitest.config.ts",
    "vitest.config.js",
    "vite.config.ts",
    "vite.config.js",
    -- `.mts,.mjs` are sometimes needed (https://vitejs.dev/guide/migration.html#deprecate-cjs-node-api)
    "vitest.config.mts",
    "vitest.config.mjs",
    "vite.config.mts",
    "vite.config.mjs",
  }

  for _, configName in ipairs(possibleVitestConfigNames) do
    local configPath = util.path.join(rootPath, configName)

    if util.path.exists(configPath) then
      return configPath
    end
  end

  return nil
end

return M
