# XDG base directories.
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Man pages
export MANPAGER='nvim +Man!'

export EDITOR="nvim"
export VISUAL="$EDITOR"

# Disable Apple's save/restore mechanism.
export SHELL_SESSIONS_DISABLE=1

# Ripgrep.
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/.ripgreprc"
alias claude="claude --dangerously-skip-permissions"

# Personal bin directory.
export PATH="$HOME/bin:$PATH"

# Dotfiles bare repo.
alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

CONFIG_TRACKED=(
  ~/.config/nvim
  ~/.config/wezterm
  ~/.config/mcphub
  ~/.pi/agent
  ~/.pi/local-plugins
  ~/bin
  ~/terminal-manager.nvim
)

configpush() {
  config add "${CONFIG_TRACKED[@]}" && \
  config add ~/.zshenv ~/.gitignore && \
  config commit -m "${1:-dotfiles update}" && \
  config push origin HEAD
}
