# TUI apps render dashes instead of empty space

TUI applications (Claude CLI, opencode, etc.) display `-` characters where empty space should be when opened via ergoterm.

Works correctly with `:terminal claude` - issue only occurs through ergoterm.

## Cause

`_set_win_options` in `instance/open.lua` doesn't disable `list`. When using LazyVim (or any config with `list = true`), ergoterm windows inherit this setting, causing listchars to render in the terminal.

## Fix

Add to `_set_win_options`:
```lua
vim.api.nvim_set_option_value("list", false, { scope = "local", win = window })
```

**Screenshot:**
<!-- paste here -->
