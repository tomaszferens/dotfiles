local util = require("utils.util")

local M = {}

M.getDefaultCommand = function(path, test_runner)
  local rootPath = util.find_node_modules_ancestor(path)
  local binary = util.path.join(rootPath, "node_modules", ".bin", test_runner)

  if util.path.exists(binary) then
    return binary
  end

  local gitRootPath = util.find_git_ancestor(path)
  if gitRootPath then
    binary = util.path.join(gitRootPath, "node_modules", ".bin", test_runner)
    if util.path.exists(binary) then
      return binary
    end
  end

  return test_runner
end

M.getCommandTestScript = function(path)
  local nearest_package_json = util.path.join(util.find_package_json_ancestor(path), "package.json")

  if nearest_package_json and vim.fn.filereadable(nearest_package_json) == 1 then
    local content = vim.fn.json_decode(vim.fn.readfile(nearest_package_json))
    if content.scripts and content.scripts.test then
      return "npm run test --"
    end
  end

  return nil
end

M.getTestCommand = function(path, test_runner)
  local cwd = vim.fn.getcwd()
  local root_jest_projects = { "vinny" }
  for _, project in ipairs(root_jest_projects) do
    if vim.endswith(cwd, project) then
      return cwd .. "/node_modules/.bin/" .. test_runner
    end
  end

  local app_specific_vitest = require("utils.app_specific_vitest")

  for _, path_pattern in ipairs(app_specific_vitest) do
    if string.find(path, path_pattern) then
      local removed = util.remove_parts(path_pattern)
      if removed == "" then
        return cwd .. "/node_modules/.bin/" .. test_runner
      end

      return cwd .. "/" .. removed .. "/node_modules/.bin/" .. test_runner
    end
  end

  return M.getCommandTestScript(path) or M.getDefaultCommand(path, test_runner)
end

return M
