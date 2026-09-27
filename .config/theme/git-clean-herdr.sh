#!/bin/sh
# git clean filter for ~/.config/herdr/config.toml (wired up in ~/.gitattributes
# and by configpush in ~/.zshenv). apply.sh rewrites the theme-toggle block
# on every theme switch; this commits it as the default theme instead, so the
# selected theme never shows up as a dotfiles change.
exec awk -v frag="$(dirname "$0")/themes/tokyonight/herdr.toml" '
  /^# >>> theme-toggle/ { print; while ((getline line < frag) > 0) print line; skip = 1; next }
  /^# <<< theme-toggle/ { skip = 0 }
  !skip
'
