#!/bin/sh
# Debounced preview for pick.sh's fzf focus event. Returns at once so cursor
# movement stays responsive; the theme is applied only if the cursor has not
# moved on within the delay (each call overwrites .pending with its own token).
dir="$HOME/.config/theme"
token="$1.$$"
echo "$token" >"$dir/.pending"
(
  sleep 0.15
  [ "$(cat "$dir/.pending")" = "$token" ] || exit 0
  "$dir/apply.sh" --if-pending "$token" --preview "$1"
) </dev/null >/dev/null 2>&1 &
