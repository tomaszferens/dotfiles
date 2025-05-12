local util = require("utils.util")

local M = {}

-- Parse a package.json file and extract dependencies
local function parse_package_json(file_path)
  local result = { dependencies = {}, name = "" }

  -- Check if file exists
  if vim.fn.filereadable(file_path) == 0 then
    return result
  end

  local content = ""
  local file = io.open(file_path, "r")
  if file then
    content = file:read("*all")
    file:close()
  else
    return result
  end

  -- Parse JSON content
  local ok, parsed = pcall(vim.json.decode, content)
  if not ok or type(parsed) ~= "table" then
    return result
  end

  -- Extract package name and dependencies
  result.name = parsed.name or ""
  result.dependencies = parsed.dependencies or {}

  return result
end

-- Find all package.json files in the given directory and its subdirectories
local function find_package_jsons(root_dir)
  local packages = {}

  -- Check for root package.json
  local root_package_path = root_dir .. "/package.json"
  if vim.fn.filereadable(root_package_path) == 1 then
    packages.root = parse_package_json(root_package_path)
  end

  -- Check for special directories: apps, packages, libs
  local special_dirs = { "apps", "packages", "libs" }
  for _, dir in ipairs(special_dirs) do
    local special_dir_path = root_dir .. "/" .. dir

    if vim.fn.isdirectory(special_dir_path) == 1 then
      packages[dir] = {}

      -- Get all subdirectories
      local subdirs = vim.fn.glob(special_dir_path .. "/*", false, true)
      for _, subdir in ipairs(subdirs) do
        if vim.fn.isdirectory(subdir) == 1 then
          local subdir_name = vim.fn.fnamemodify(subdir, ":t")
          local package_path = subdir .. "/package.json"

          if vim.fn.filereadable(package_path) == 1 then
            packages[dir][subdir_name] = parse_package_json(package_path)
          end
        end
      end
    end
  end

  return packages
end

-- Generate system prompt based on project dependencies
local function generate_typescript_project_system_prompt(packages)
  local prompt = ""
  local project_data = {
    root = nil,
    packages = {},
  }

  -- Organize data first
  if packages.root then
    project_data.root = {
      name = packages.root.name ~= "" and packages.root.name or "Root Package",
      dependencies = packages.root.dependencies or {},
    }
  end

  -- Organize special directories data
  local special_dirs = { "apps", "packages", "libs" }
  for _, dir in ipairs(special_dirs) do
    if packages[dir] and next(packages[dir]) ~= nil then
      for subdir_name, package_info in pairs(packages[dir]) do
        local display_name = subdir_name
        if package_info.name and package_info.name ~= "" and package_info.name ~= subdir_name then
          display_name = display_name .. " (" .. package_info.name .. ")"
        end

        local package_key = dir .. "/" .. subdir_name
        project_data.packages[package_key] = {
          display_name = display_name,
          dependencies = package_info.dependencies or {},
          type = dir,
        }
      end
    end
  end

  -- Now generate the prompt with the organized data
  -- First, create a project structure tree
  prompt = prompt
    .. 'You are inside a TypeScript project named "'
    .. project_data.root.name
    .. '".\n\nHere is a project structure:\n'

  -- Add special directories to the tree
  local dir_packages = {}
  for package_key, package_data in pairs(project_data.packages) do
    local dir = package_data.type
    if not dir_packages[dir] then
      dir_packages[dir] = {}
    end
    table.insert(dir_packages[dir], package_key)
  end

  for _, dir in ipairs(special_dirs) do
    if dir_packages[dir] and #dir_packages[dir] > 0 then
      prompt = prompt .. "- " .. dir .. ":\n"

      -- Sort subdirectories for consistent output
      table.sort(dir_packages[dir])

      for _, package_key in ipairs(dir_packages[dir]) do
        prompt = prompt .. "  - " .. project_data.packages[package_key].display_name .. "\n"
      end
    end
  end

  -- Then, list dependencies by package
  prompt = prompt .. "\nDependencies by package:\n"

  -- Root package dependencies
  if project_data.root and next(project_data.root.dependencies) ~= nil then
    prompt = prompt .. "\n" .. project_data.root.name .. ":\n"

    -- Sort dependencies
    local sorted_deps = {}
    for dep, _ in pairs(project_data.root.dependencies) do
      table.insert(sorted_deps, dep)
    end
    table.sort(sorted_deps)

    for _, dep in ipairs(sorted_deps) do
      prompt = prompt .. "- " .. dep .. ": " .. project_data.root.dependencies[dep] .. "\n"
    end
  end

  -- Special directories dependencies
  local sorted_packages = {}
  for package_key, _ in pairs(project_data.packages) do
    table.insert(sorted_packages, package_key)
  end
  table.sort(sorted_packages)

  for _, package_key in ipairs(sorted_packages) do
    local package_data = project_data.packages[package_key]

    if next(package_data.dependencies) ~= nil then
      prompt = prompt .. "\n" .. package_data.display_name .. ":\n"

      -- Sort dependencies
      local sorted_deps = {}
      for dep, _ in pairs(package_data.dependencies) do
        table.insert(sorted_deps, dep)
      end
      table.sort(sorted_deps)

      for _, dep in ipairs(sorted_deps) do
        prompt = prompt .. "- " .. dep .. ": " .. package_data.dependencies[dep] .. "\n"
      end
    end
  end

  -- If no dependencies were found
  if not project_data.root and not next(project_data.packages) then
    prompt = prompt .. "\nNo dependencies found in the project.\n"
  end

  return prompt
end

local typescript_base_prompt = [[
You are currently inside a TypeScript project.

# Code Rules & Standards:
- Prefer function declarations over variable declarations for functions.
- Use interfaces instead of types for type declarations.
- Do not destructure object arguments in function parameters.
- Do not destructure props in React components, unless you want to specify the default value of a prop.
]]

-- Get system prompt for the current project
function M.get_system_prompt()
  local cwd = vim.fn.getcwd()

  -- Check if package.json exists at the root of the project using util functions
  if util.path.is_file(util.path.join(cwd, "package.json")) then
    -- Find package.json files and generate prompt
    local packages = find_package_jsons(cwd)
    local prompt = generate_typescript_project_system_prompt(packages)
    return typescript_base_prompt .. "\n" .. prompt
  else
    -- No package.json at root, return empty string or a default message
    return ""
  end
end

return M
