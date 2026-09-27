#!/bin/sh
# Theme picker (herdr popup on alt+shift+o). Moving the cursor previews the
# theme live everywhere (debounced, see preview.sh); Enter keeps it, Esc
# restores the one you started with.
set -eu

dir="$HOME/.config/theme"
start=$(cat "$dir/current" 2>/dev/null || echo tokyonight)

list() {
  for t in "$dir"/themes/*/theme; do
    name=$(basename "$(dirname "$t")")
    mode=$(sed -n 's/^mode=//p' "$t")
    printf '%s %s\n' "$mode" "$name"
  done | sort -k1,1r -k2,2 | awk '{ printf "%-28s %s\n", $2, $1 }'
}

pick=$(list | fzf \
  --nth 1 --no-sort --layout reverse \
  --prompt 'theme> ' --header 'enter: keep   esc: revert' \
  --bind "start:unbind(focus)" \
  --bind "load:pos($(list | awk -v s="$start" '$1 == s { print NR }'))+rebind(focus)" \
  --bind "focus:execute-silent($dir/preview.sh {1})" \
  | awk '{ print $1 }') || true

# Cancel any preview still waiting out its debounce, then apply for real.
echo final >"$dir/.pending"
if [ -n "$pick" ]; then
  "$dir/apply.sh" "$pick"
else
  "$dir/apply.sh" "$start"
fi
