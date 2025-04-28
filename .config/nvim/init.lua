-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local home = os.getenv("HOME")
local rgignore_path = home .. "/.rgignore"
local rgignore_file = io.open(rgignore_path, "r")

if not rgignore_file then
  rgignore_file = io.open(rgignore_path, "w")
  if rgignore_file then
    rgignore_file:write("!.env*\n")
    rgignore_file:close()
  end
else
  rgignore_file:close()
end
