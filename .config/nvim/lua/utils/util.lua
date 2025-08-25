local validate = vim.validate
local uv = vim.loop

local M = {}

function M.root_pattern(...)
  local patterns = vim.tbl_flatten({ ... })
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      for _, p in ipairs(vim.fn.glob(M.path.join(path, pattern), true, true)) do
        if M.path.exists(p) then
          return path
        end
      end
    end
  end
  return function(startpath)
    return M.search_ancestors(startpath, matcher)
  end
end

-- Some path utilities
M.path = (function()
  local is_windows = uv.os_uname().version:match("Windows")

  local function sanitize(path)
    if is_windows then
      path = path:sub(1, 1):upper() .. path:sub(2)
      path = path:gsub("\\", "/")
    end
    return path
  end

  local function exists(filename)
    local stat = uv.fs_stat(filename)
    return stat and stat.type or false
  end

  local function is_dir(filename)
    return exists(filename) == "directory"
  end

  local function is_file(filename)
    return exists(filename) == "file"
  end

  local function is_fs_root(path)
    if is_windows then
      return path:match("^%a:$")
    else
      return path == "/"
    end
  end

  local function is_absolute(filename)
    if is_windows then
      return filename:match("^%a:") or filename:match("^\\\\")
    else
      return filename:match("^/")
    end
  end

  local function dirname(path)
    local strip_dir_pat = "/([^/]+)$"
    local strip_sep_pat = "/$"
    if not path or #path == 0 then
      return
    end
    local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
    if #result == 0 then
      if is_windows then
        return path:sub(1, 2):upper()
      else
        return "/"
      end
    end
    return result
  end

  local function path_join(...)
    return table.concat(vim.tbl_flatten({ ... }), "/")
  end

  -- Traverse the path calling cb along the way.
  local function traverse_parents(path, cb)
    path = uv.fs_realpath(path)
    local dir = path
    -- Just in case our algo is buggy, don't infinite loop.
    for _ = 1, 100 do
      dir = dirname(dir)
      if not dir then
        return
      end
      -- If we can't ascend further, then stop looking.
      if cb(dir, path) then
        return dir, path
      end
      if is_fs_root(dir) then
        break
      end
    end
  end

  -- Iterate the path until we find the rootdir.
  local function iterate_parents(path)
    local function it(_, v)
      if v and not is_fs_root(v) then
        v = dirname(v)
      else
        return
      end
      if v and uv.fs_realpath(v) then
        return v, path
      else
        return
      end
    end
    return it, path, path
  end

  local function is_descendant(root, path)
    if not path then
      return false
    end

    local function cb(dir, _)
      return dir == root
    end

    local dir, _ = traverse_parents(path, cb)

    return dir == root
  end

  local path_separator = is_windows and ";" or ":"

  return {
    is_dir = is_dir,
    is_file = is_file,
    is_absolute = is_absolute,
    exists = exists,
    dirname = dirname,
    join = path_join,
    sanitize = sanitize,
    traverse_parents = traverse_parents,
    iterate_parents = iterate_parents,
    is_descendant = is_descendant,
    path_separator = path_separator,
  }
end)()

function M.search_ancestors(startpath, func)
  validate({ func = { func, "f" } })
  if func(startpath) then
    return startpath
  end
  local guard = 100
  for path in M.path.iterate_parents(startpath) do
    -- Prevent infinite recursion if our algorithm breaks
    guard = guard - 1
    if guard == 0 then
      return
    end

    if func(path) then
      return path
    end
  end
end

function M.find_git_ancestor(startpath)
  return M.search_ancestors(startpath, function(path)
    -- .git is a file when the project is a git worktree or it's a directory if it's a regular project
    if M.path.is_file(M.path.join(path, ".git")) or M.path.is_dir(M.path.join(path, ".git")) then
      return path
    end
  end)
end

function M.find_node_modules_ancestor(startpath)
  return M.search_ancestors(startpath, function(path)
    if M.path.is_dir(M.path.join(path, "node_modules")) then
      return path
    end
  end)
end

function M.find_package_json_ancestor(startpath)
  return M.search_ancestors(startpath, function(path)
    if M.path.is_file(M.path.join(path, "package.json")) then
      return path
    end
  end)
end

function M.find_project_json_ancestor(startpath)
  return M.search_ancestors(startpath, function(path)
    if M.path.is_file(M.path.join(path, "project.json")) then
      return path
    end
  end)
end

M.remove_parts = function(path_pattern, num_parts)
  num_parts = num_parts or 1
  local parts = vim.split(path_pattern, "/")
  for _ = 1, num_parts do
    table.remove(parts, 1)
  end
  return table.concat(parts, "/")
end

function M.find_terminal_buffer_by_names(candidate_names)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      for _, name in ipairs(candidate_names) do
        if buf_name:match(name) then
          return bufnr
        end
      end
    end
  end
  return nil
end

function M.find_window_with_buffer(bufnr)
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winnr) == bufnr then
      return winnr
    end
  end
  return nil
end

-- Check if a terminal buffer is visible in any window
function M.is_terminal_visible(bufnr)
  return M.find_window_with_buffer(bufnr) ~= nil
end

-- Generic function to focus or create a terminal
-- terminal_configs: array of {names, create_command} tables
-- Prioritizes visible terminals first, then searches by order
function M.focus_or_create_terminal(terminal_configs)
  -- First pass: check for visible terminals
  for _, config in ipairs(terminal_configs) do
    local bufnr = M.find_terminal_buffer_by_names(config.names)
    if bufnr and M.is_terminal_visible(bufnr) then
      local winnr = M.find_window_with_buffer(bufnr)
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("startinsert")
      return true
    end
  end
  
  -- Second pass: check for existing but not visible terminals
  for _, config in ipairs(terminal_configs) do
    local bufnr = M.find_terminal_buffer_by_names(config.names)
    if bufnr then
      -- Buffer exists but no window, open it
      vim.cmd("buffer " .. bufnr)
      vim.cmd("startinsert")
      return true
    end
  end
  
  -- No existing terminals found, create the first one
  if #terminal_configs > 0 then
    terminal_configs[1].create_command()
    return true
  end
  
  return false
end

return M
