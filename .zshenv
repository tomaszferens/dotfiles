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

# New terminal window — run any command in a new WezTerm window.
ntw() {
  if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: ntw <command>"
    echo ""
    echo "Spawns a new WezTerm window and runs <command> in it."
    echo ""
    echo "Examples:"
    echo "  ntw \"claude \"prompt goes here\"\""
    echo "  ntw \"codex \"prompt goes here\"\""
    echo "  ntw \"pi \"prompt goes here\"\""
    echo "  ntw \"htop\""
    echo "  ntw \"ls\""
    return 0
  fi
  wezterm cli spawn --new-window -- zsh -ic "$*; exec zsh"
}
