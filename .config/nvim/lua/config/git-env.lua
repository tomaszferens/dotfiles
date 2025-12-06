-- Global bare repo detection for dotfiles
-- Sets GIT_DIR and GIT_WORK_TREE when not in a normal git repo but under ~
-- This makes all git-using plugins work with bare repo dotfiles

local bare_repo = vim.fn.expand("~/.cfg")
local home = vim.fn.expand("~")

local function update_git_env()
  local cwd = vim.fn.getcwd()

  -- Temporarily clear env vars so git rev-parse checks for actual .git directory
  vim.env.GIT_DIR = nil
  vim.env.GIT_WORK_TREE = nil

  -- Check if we're in a normal git repo (has .git)
  local git_dir = vim.fn.systemlist("git rev-parse --git-dir 2>/dev/null")[1]

  if git_dir and git_dir ~= "" then
    -- In a normal git repo - keep env vars cleared
    return
  elseif vim.fn.isdirectory(bare_repo) == 1 and cwd:find(home, 1, true) == 1 then
    -- Not in a git repo, but under home with bare repo available
    vim.env.GIT_DIR = bare_repo
    vim.env.GIT_WORK_TREE = home
  end
  -- Otherwise env vars stay cleared
end

vim.api.nvim_create_augroup("BareRepoDetect", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  group = "BareRepoDetect",
  callback = update_git_env,
})

-- Run immediately for current session
update_git_env()
