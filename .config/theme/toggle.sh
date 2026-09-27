#!/bin/sh
# Flip between the last light and last dark theme picked with pick.sh
# (herdr alt+shift+c). Falls back to github-light / tokyonight.
set -eu

dir="$HOME/.config/theme"
current=$(cat "$dir/current" 2>/dev/null || echo tokyonight)
mode=$(sed -n 's/^mode=//p' "$dir/themes/$current/theme" 2>/dev/null || echo dark)
if [ "$mode" = dark ]; then
  target=$(cat "$dir/last-light" 2>/dev/null || echo github-light)
else
  target=$(cat "$dir/last-dark" 2>/dev/null || echo tokyonight)
fi
exec "$dir/apply.sh" "$target"
