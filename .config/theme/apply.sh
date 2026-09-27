#!/bin/sh
# Apply one theme from ~/.config/theme/themes/<name>/ to Ghostty, herdr, every
# running Neovim and Claude Code.
#
# Only the files in .gitignore change per machine; the dotfiles stay clean
# (herdr's config.toml goes through git-clean-herdr.sh, see ~/.gitattributes).
#
#   apply.sh <name>            apply and remember it (current, last-<mode>)
#   apply.sh --preview <name>  apply but only update `current` (used by pick.sh)
#   apply.sh --if-pending <token> --preview <name>
#                              skip unless .pending still holds <token>
#                              (debounced previews from preview.sh)
#
# Runs are serialized with lockf on .lock, so overlapping previews cannot
# leave the apps on different themes.
#
# Each theme directory holds:
#   theme         mode=light|dark, nvim=<colorscheme>
#   ghostty.conf  copied to ghostty.conf, included by ~/.config/ghostty/config
#   herdr.toml    spliced between the theme-toggle markers in herdr's config.toml
set -eu

dir="$HOME/.config/theme"
if [ -z "${THEME_APPLY_LOCKED:-}" ]; then
  THEME_APPLY_LOCKED=1 exec lockf -k "$dir/.lock" "$0" "$@"
fi
if [ "${1:-}" = --if-pending ]; then
  [ "$(cat "$dir/.pending" 2>/dev/null)" = "$2" ] || exit 0
  shift 2
fi
preview=false
[ "${1:-}" = --preview ] && { preview=true; shift; }
name=${1:?usage: apply.sh [--preview] <theme>}
theme="$dir/themes/$name"
[ -f "$theme/theme" ] || { echo "no theme: $name" >&2; exit 1; }
mode=$(sed -n 's/^mode=//p' "$theme/theme")
nvim_scheme=$(sed -n 's/^nvim=//p' "$theme/theme")

echo "$name" >"$dir/current"
$preview || echo "$name" >"$dir/last-$mode"

# Ghostty: swap the included file and reload through AppleScript (Ghostty 1.3+).
cp "$theme/ghostty.conf" "$dir/ghostty.conf"
if pgrep -xq ghostty; then
  osascript -e 'tell application "Ghostty" to perform action "reload_config" on first terminal' >/dev/null 2>&1 || true
fi

# herdr: replace everything between the markers, then reload the server.
herdr_conf="$HOME/.config/herdr/config.toml"
tmp="$herdr_conf.tmp.$$"
awk -v frag="$theme/herdr.toml" '
  /^# >>> theme-toggle/ { print; while ((getline line < frag) > 0) print line; skip = 1; next }
  /^# <<< theme-toggle/ { skip = 0 }
  !skip
' "$herdr_conf" >"$tmp" && mv "$tmp" "$herdr_conf"
herdr="${HERDR_BIN_PATH:-$(command -v herdr || echo "$HOME/.local/bin/herdr")}"
"$herdr" server reload-config >/dev/null 2>&1 || true

# Claude Code: settings.json keeps "theme": "auto", so it asks the terminal
# (herdr) for its background at startup and again whenever it receives a
# theme-change notification (CSI ?997;1n dark, ?997;2n light). herdr answers
# the question but never sends the notification, so send it to every Claude
# pane ourselves. Only Claude panes: anything else would get it as typed text.
[ "$mode" = dark ] && notify=1 || notify=2
"$herdr" pane list 2>/dev/null |
  jq -r '.result.panes[] | select(.agent == "claude") | .pane_id' |
  while read -r pane; do
    "$herdr" pane send-text "$pane" "$(printf '\033[?997;%sn' "$notify")" >/dev/null 2>&1 || true
  done

# Neovim: lua/utils/theme.lua reads this file at startup and on the remote
# call below. Every instance listens on /tmp/nvim-*.sock (lua/config/options.lua);
# stale sockets just fail, and each call runs in the background so one busy
# instance cannot hold up the rest.
echo "$mode $nvim_scheme" >"$dir/nvim"
for sock in /tmp/nvim-*.sock; do
  [ -S "$sock" ] || continue
  nvim --server "$sock" --remote-expr 'luaeval("dofile(vim.fn.stdpath([[config]]) .. [[/lua/utils/theme.lua]]).apply()")' >/dev/null 2>&1 &
done
