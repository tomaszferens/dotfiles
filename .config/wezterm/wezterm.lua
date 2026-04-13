local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action
local config = wezterm.config_builder()
local on_mac = wezterm.target_triple == 'aarch64-apple-darwin'

-- Font configuration
local font_family = 'JetBrainsMono Nerd Font'
local font_size = on_mac and 14 or 20
local frame_font_size = on_mac and 14 or 18

-- Color theme.
local colors = {
    bg = '#1a1b26',
    black = '#15161e',
    dark_lilac = '#565f89',
    lilac = '#9aa5ce',
}

config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.front_end = 'WebGpu'

-- Shift+Click bypasses tmux mouse capture to open URLs.
config.bypass_mouse_reporting_modifiers = 'SHIFT'

config.color_scheme = 'Tokyo Night'
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
    font = wezterm.font(font_family, { weight = 'Regular' }),
    font_size = frame_font_size,
    active_titlebar_bg = colors.bg,
    inactive_titlebar_bg = colors.bg,
}

-- Fonts.
config.font_size = font_size
config.cell_width = 0.9
config.line_height = on_mac and 1.2 or 1.25
config.font = wezterm.font(font_family, { weight = 'Regular', stretch = 'Normal' })

-- Make underlines THICK.
config.underline_position = -6
config.underline_thickness = '250%'

-- Project workspace launcher.
local function project_workspace()
    return wezterm.action_callback(function(window, pane)
        local home = os.getenv 'HOME'
        local projects_dir = home .. '/projects'

        -- Get existing workspaces (fresh check each time)
        local existing_workspaces = {}
        for _, name in ipairs(mux.get_workspace_names()) do
            existing_workspaces[name] = true
        end

        local projects = {}
        for _, entry in ipairs(wezterm.glob(projects_dir .. '/*')) do
            local name = entry:match '([^/]+)$'
            -- Mark existing workspaces in the label
            local label = existing_workspaces[name] and name .. ' *' or name
            table.insert(projects, { id = entry, label = label })
        end

        window:perform_action(
            act.InputSelector {
                title = 'Select Project (* = running)',
                choices = projects,
                action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
                    if not id then
                        return
                    end

                    -- Remove the " *" suffix if present to get the actual workspace name
                    local workspace_name = label:gsub(' %*$', '')

                    -- If workspace already exists, just switch to it
                    if existing_workspaces[workspace_name] then
                        mux.set_active_workspace(workspace_name)
                        return
                    end

                    local tab, first_pane, new_window = mux.spawn_window {
                        workspace = workspace_name,
                        cwd = id,
                    }

                    local second_tab, second_pane, _ = new_window:spawn_tab { cwd = id }
                    second_pane:split { direction = 'Bottom', cwd = id }

                    -- Go back to first tab and launch nvim
                    tab:activate()
                    first_pane:send_text 'nvim\n'

                    mux.set_active_workspace(workspace_name)
                end),
            },
            pane
        )
    end)
end

-- Keybindings.
local function pane_navigation_action(direction, fallback_direction)
    return wezterm.action_callback(function(win, pane)
        local num_panes = #win:active_tab():panes()
        local pane_direction = num_panes == 2 and fallback_direction or direction
        win:perform_action({ ActivatePaneDirection = pane_direction }, pane)
    end)
end
local mods = 'ALT|SHIFT'
config.keys = {
    { mods = mods, key = 'x', action = act.ActivateCopyMode },
    { mods = mods, key = 'd', action = act.ShowDebugOverlay },
    { mods = mods, key = 'v', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { mods = mods, key = 's', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { mods = mods, key = 'h', action = pane_navigation_action('Left', 'Prev') },
    { mods = mods, key = 'l', action = pane_navigation_action('Right', 'Next') },
    { mods = mods, key = 'k', action = pane_navigation_action('Up', 'Prev') },
    { mods = mods, key = 'j', action = pane_navigation_action('Down', 'Next') },
    { mods = mods, key = 't', action = act.SpawnTab 'CurrentPaneDomain' },
    { mods = mods, key = 'q', action = act.CloseCurrentPane { confirm = true } },
    { mods = mods, key = 'y', action = act.CopyTo 'Clipboard' },
    { mods = mods, key = 'p', action = act.PasteFrom 'Clipboard' },
    { mods = mods, key = 'w', action = project_workspace() },
    {
        mods = 'CTRL|ALT',
        key = 'w',
        action = wezterm.action_callback(function(win, pane)
            local workspace = win:active_workspace()
            for _, w in ipairs(mux.all_windows()) do
                if w:get_workspace() == workspace then
                    w:gui_window():perform_action(act.CloseCurrentTab { confirm = false }, pane)
                end
            end
        end),
    },
    {
        mods = mods,
        key = 'r',
        action = wezterm.action_callback(function(win, pane)
            win:perform_action(
                act.InputSelector {
                    title = 'Run in new window:',
                    choices = {
                        { id = 'ls', label = 'ls' },
                        { id = 'htop', label = 'htop' },
                    },
                    action = wezterm.action_callback(function(_, _, id)
                        if not id then
                            return
                        end
                        local _, first_pane, _ = mux.spawn_window {}
                        first_pane:send_text(id .. '\n')
                    end),
                },
                pane
            )
        end),
    },
    {
        mods = mods,
        key = 'm',
        action = wezterm.action_callback(function(win, pane)
            pane:send_text 'nvim\n'
            local bottom = pane:split { direction = 'Bottom', size = 0.3 }
            bottom:send_text 'tmux\n'
        end),
    },
    {
        mods = mods,
        key = 'e',
        action = wezterm.action_callback(function(win, pane)
            local cwd = pane:get_current_working_dir()
            local mux_win = win:mux_window()
            local old_tab = win:active_tab()
            local old_idx = 0
            for i, t in ipairs(mux_win:tabs()) do
                if t:tab_id() == old_tab:tab_id() then
                    old_idx = i - 1
                    break
                end
            end
            win:perform_action(act.SpawnCommandInNewTab { cwd = cwd and cwd.file_path or nil }, pane)
            win:perform_action(act.ActivateTabRelative(-1), pane)
            win:perform_action(act.CloseCurrentTab { confirm = false }, pane)
            win:perform_action(act.MoveTab(old_idx), pane)
        end),
    },
    { mods = mods, key = 'n', action = act.SwitchWorkspaceRelative(1) },
    { mods = mods, key = 'b', action = act.SwitchWorkspaceRelative(-1) },
    {
        mods = 'ALT',
        key = 'a',
        action = wezterm.action_callback(function(win, pane)
            -- If this pane is running neovim, pass the key through
            local process = pane:get_foreground_process_name() or ''
            local is_nvim = process:match 'nvim$' ~= nil

            if is_nvim then
                win:perform_action(act.SendKey { mods = 'ALT', key = 'a' }, pane)
                return
            end

            -- Find the nvim pane in this tab to use its per-pane socket
            local nvim_pane_id = nil
            for _, p in ipairs(win:active_tab():panes()) do
                local proc = p:get_foreground_process_name() or ''
                if proc:match 'nvim$' then
                    nvim_pane_id = p:pane_id()
                    break
                end
            end
            if not nvim_pane_id then
                wezterm.log_info 'M-a: no nvim pane found in current tab'
                return
            end

            local sock = '/tmp/nvim-wezterm-' .. tostring(nvim_pane_id) .. '.sock'
            local handle_which = io.popen('/bin/zsh -lc "which nvim" 2>/dev/null')
            local nvim_bin = handle_which and handle_which:read('*l') or 'nvim'
            if handle_which then handle_which:close() end
            local cmd = nvim_bin
                .. ' --server '
                .. sock
                .. ' --remote-expr "expand(\'%:.\')" 2>&1'
            wezterm.log_info('M-a: running: ' .. cmd)

            local handle = io.popen(cmd)
            if not handle then
                wezterm.log_info 'M-a: io.popen failed'
                return
            end
            local file_path = handle:read '*a'
            local ok, exit_type, code = handle:close()
            wezterm.log_info(
                ('M-a: result=%q ok=%s exit=%s code=%s'):format(
                    file_path or 'nil',
                    tostring(ok),
                    tostring(exit_type),
                    tostring(code)
                )
            )

            file_path = (file_path or ''):gsub('%s+$', '')
            if file_path ~= '' and not file_path:match 'E%d+:' then
                pane:send_text('@' .. file_path .. ' ')
            else
                wezterm.log_info('M-a: skipped, bad result: ' .. file_path)
            end
        end),
    },
    { mods = 'ALT', key = 'f', action = act { ActivatePaneDirection = 'Next' } },
    { mods = 'ALT', key = '-', action = act.DecreaseFontSize },
    { mods = 'ALT', key = '=', action = act.IncreaseFontSize },
    { mods = 'ALT', key = '0', action = act.ResetFontSize },
    { mods = 'ALT', key = '1', action = act.ActivateTab(0) },
    { mods = 'ALT', key = '2', action = act.ActivateTab(1) },
    { mods = 'ALT', key = '3', action = act.ActivateTab(2) },
    { mods = 'ALT', key = '4', action = act.ActivateTab(3) },
    { mods = 'ALT', key = '5', action = act.ActivateTab(4) },
    { mods = 'ALT', key = '6', action = act.ActivateTab(5) },
    { mods = 'ALT', key = '7', action = act.ActivateTab(6) },
    { mods = 'ALT', key = '8', action = act.ActivateTab(7) },
    { mods = 'ALT', key = '9', action = act.ActivateTab(8) },
    { key = 'LeftArrow', mods = 'ALT', action = wezterm.action { SendString = '\x1bb' } },
    -- Make Option-Right equivalent to Alt-f; forward-word
    { key = 'RightArrow', mods = 'ALT', action = wezterm.action { SendString = '\x1bf' } },
    {
        key = ',',
        mods = 'CTRL|ALT',
        action = act.AdjustPaneSize { 'Left', 5 },
    },
    {
        mods = 'CTRL|ALT',
        key = 's',
        action = act.AdjustPaneSize { 'Down', 5 },
    },
    { key = 't', mods = 'CTRL|ALT', action = act.AdjustPaneSize { 'Up', 5 } },
    {
        key = '.',
        mods = 'CTRL|ALT',
        action = act.AdjustPaneSize { 'Right', 5 },
    },
    {
        key = 'U',
        mods = 'SHIFT|CTRL',
        action = act.DisableDefaultAssignment,
    },
    {
        key = '=',
        mods = 'CTRL',
        action = act.DisableDefaultAssignment,
    },
}
-- I just need to toggle fullscreen on Mac. On Linux I use the window manager.
if on_mac then
    table.insert(config.keys, { mods = mods, key = 'Enter', action = act.ToggleFullScreen })
end

wezterm.on('format-tab-title', function(tab)
    -- Get the process name.
    local process = string.gsub(tab.active_pane.foreground_process_name, '(.*[/\\])(.*)', '%2')

    -- Current working directory.
    local cwd = tab.active_pane.current_working_dir
    cwd = cwd and string.format('%s ', cwd.file_path:gsub(os.getenv 'HOME', '~')) or ''

    -- Format and return the title.
    return string.format('(%d %s) %s', tab.tab_index + 1, process, cwd)
end)

wezterm.on('gui-startup', function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

return config
