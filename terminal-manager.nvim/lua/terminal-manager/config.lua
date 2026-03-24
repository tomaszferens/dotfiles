local M = {}

M.defaults = {
	shell = vim.o.shell,
	size = 70,
	close_on_exit = true,
	start_in_insert = true,
	sidebar_width = 22,
	display_mode = "horizontal", -- "horizontal" | "vertical" | "float"
	border = "rounded",          -- border style for float mode
	escape_key = "<Esc>",        -- key to exit terminal mode and close the terminal window; false to disable
	auto_rename = true,          -- auto-rename tabs to the active process (b:term_title); manual renames stick
	colors = { bg = nil, fg = nil },
}

M.options = {}

---Merge `opts` with `M.defaults` and store the result in `M.options`.
---Called once from `terminal-manager.setup()` during plugin initialisation.
---@param opts? {shell?:string, size?:integer, close_on_exit?:boolean, start_in_insert?:boolean, sidebar_width?:integer, display_mode?:"horizontal"|"vertical"|"float", border?:string, escape_key?:string|false, colors?:{bg?:string, fg?:string}}
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
