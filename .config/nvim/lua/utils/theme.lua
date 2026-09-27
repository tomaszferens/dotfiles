-- Colorscheme picked by ~/.config/theme (pick.sh on alt+shift+o, toggle.sh on
-- alt+shift+c in herdr). apply.sh writes "<background> <colorscheme>" to
-- ~/.config/theme/nvim and runs this file in every running instance over its
-- /tmp/nvim-*.sock server (with dofile, so edits here reach old instances).
local M = {}

-- A colorscheme plugin installed after this instance started is not in its
-- lazy spec; put the plugin that ships colors/<scheme> on the runtimepath.
local function load_from_lazy_dir(scheme)
  local files = vim.fn.glob(vim.fn.stdpath("data") .. "/lazy/*/colors/" .. scheme .. ".*", false, true)
  if #files == 0 then
    return false
  end
  vim.opt.rtp:prepend(vim.fs.dirname(vim.fs.dirname(files[1])))
  return pcall(vim.cmd.colorscheme, scheme)
end

function M.apply()
  local f = io.open(vim.fn.expand("~/.config/theme/nvim"))
  local line = f and f:read("*l") or ""
  if f then
    f:close()
  end
  local bg, scheme = line:match("^(%S+)%s+(%S+)")
  bg, scheme = bg or "dark", scheme or "tokyonight-moon"
  vim.o.background = bg
  if not pcall(vim.cmd.colorscheme, scheme) and not load_from_lazy_dir(scheme) then
    vim.notify("theme: colorscheme " .. scheme .. " not found", vim.log.levels.WARN)
  end
end

return M
