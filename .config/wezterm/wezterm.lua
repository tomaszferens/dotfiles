local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action
local config = wezterm.config_builder()
local on_mac = wezterm.target_triple == "aarch64-apple-darwin"

-- Font configuration
local font_family = "JetBrainsMono Nerd Font"
local font_size = on_mac and 14 or 20
local frame_font_size = on_mac and 12 or 18

-- Color theme.
local colors = {
	bg = "#1a1b26",
	black = "#15161e",
	dark_lilac = "#565f89",
	lilac = "#9aa5ce",
}

config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.front_end = "WebGpu"

config.color_scheme = "Tokyo Night"
config.colors = {
	background = colors.bg,
	tab_bar = {
		inactive_tab_edge = colors.black,
		active_tab = {
			bg_color = colors.lilac,
			fg_color = colors.black,
		},
		inactive_tab = {
			bg_color = colors.black,
			fg_color = colors.dark_lilac,
		},
		inactive_tab_hover = {
			bg_color = colors.black,
			fg_color = colors.lilac,
		},
		new_tab = {
			bg_color = colors.bg,
			fg_color = colors.lilac,
		},
		new_tab_hover = {
			bg_color = colors.lilac,
			fg_color = colors.black,
		},
	},
}

-- Inactive panes.
config.inactive_pane_hsb = {
	saturation = 0.6,
	brightness = 0.6,
}

-- Remove extra space.
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

-- Native macOS fullscreen.
config.native_macos_fullscreen_mode = true

-- Cursor.
config.cursor_thickness = 2

-- Tab bar.
config.hide_tab_bar_if_only_one_tab = true
config.window_frame = {
	font = wezterm.font(font_family, { weight = "DemiBold" }),
	font_size = frame_font_size,
	active_titlebar_bg = colors.bg,
	inactive_titlebar_bg = colors.bg,
}

-- Fonts.
config.font_size = font_size
config.cell_width = 0.9
config.line_height = on_mac and 1.2 or 1.25
config.font = wezterm.font(font_family, { weight = "DemiBold" })

-- Make underlines THICK.
config.underline_position = -6
config.underline_thickness = "250%"

-- Keybindings.
local function pane_navigation_action(direction, fallback_direction)
	return wezterm.action_callback(function(win, pane)
		local num_panes = #win:active_tab():panes()
		local pane_direction = num_panes == 2 and fallback_direction or direction
		win:perform_action({ ActivatePaneDirection = pane_direction }, pane)
	end)
end
local mods = "ALT|SHIFT"
config.keys = {
	{ mods = mods, key = "x", action = act.ActivateCopyMode },
	{ mods = mods, key = "d", action = act.ShowDebugOverlay },
	{ mods = mods, key = "v", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ mods = mods, key = "s", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ mods = mods, key = "h", action = pane_navigation_action("Left", "Prev") },
	{ mods = mods, key = "l", action = pane_navigation_action("Right", "Next") },
	{ mods = mods, key = "k", action = pane_navigation_action("Up", "Prev") },
	{ mods = mods, key = "j", action = pane_navigation_action("Down", "Next") },
	{ mods = mods, key = "t", action = act.SpawnTab("CurrentPaneDomain") },
	{ mods = mods, key = "q", action = act.CloseCurrentPane({ confirm = true }) },
	{ mods = mods, key = "y", action = act.CopyTo("Clipboard") },
	{ mods = mods, key = "p", action = act.PasteFrom("Clipboard") },
	{ mods = "ALT", key = "-", action = act.DecreaseFontSize },
	{ mods = "ALT", key = "=", action = act.IncreaseFontSize },
	{ mods = "ALT", key = "0", action = act.ResetFontSize },
	{ mods = "ALT", key = "1", action = act.ActivateTab(0) },
	{ mods = "ALT", key = "2", action = act.ActivateTab(1) },
	{ mods = "ALT", key = "3", action = act.ActivateTab(2) },
	{ mods = "ALT", key = "4", action = act.ActivateTab(3) },
	{ mods = "ALT", key = "5", action = act.ActivateTab(4) },
	{ mods = "ALT", key = "6", action = act.ActivateTab(5) },
	{ mods = "ALT", key = "7", action = act.ActivateTab(6) },
	{ mods = "ALT", key = "8", action = act.ActivateTab(7) },
	{ mods = "ALT", key = "9", action = act.ActivateTab(8) },
	{ key = "LeftArrow", mods = "ALT", action = wezterm.action({ SendString = "\x1bb" }) },
	-- Make Option-Right equivalent to Alt-f; forward-word
	{ key = "RightArrow", mods = "ALT", action = wezterm.action({ SendString = "\x1bf" }) },
	{
		key = ",",
		mods = "CTRL|ALT",
		action = act.AdjustPaneSize({ "Left", 5 }),
	},
	{
		mods = "CTRL|ALT",
		key = "s",
		action = act.AdjustPaneSize({ "Down", 5 }),
	},
	{ key = "t", mods = "CTRL|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{
		key = ".",
		mods = "CTRL|ALT",
		action = act.AdjustPaneSize({ "Right", 5 }),
	},
}
-- I just need to toggle fullscreen on Mac. On Linux I use the window manager.
if on_mac then
	table.insert(config.keys, { mods = mods, key = "Enter", action = act.ToggleFullScreen })
end

wezterm.on("format-tab-title", function(tab)
	-- Get the process name.
	local process = string.gsub(tab.active_pane.foreground_process_name, "(.*[/\\])(.*)", "%2")

	-- Current working directory.
	local cwd = tab.active_pane.current_working_dir
	cwd = cwd and string.format("%s ", cwd.file_path:gsub(os.getenv("HOME"), "~")) or ""

	-- Format and return the title.
	return string.format("(%d %s) %s", tab.tab_index + 1, process, cwd)
end)

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
