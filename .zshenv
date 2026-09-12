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

# Kill detached tmux sessions.
tmux-kd() {
  tmux list-sessions -F '#{session_attached} #{session_id}' |
    awk '$1 == 0 {print $2}' |
    xargs -r -n1 tmux kill-session -t
}

# Personal bin directory.
export PATH="$HOME/bin:$PATH"

# Dotfiles bare repo.
alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

CONFIG_TRACKED=(
  ~/.config/ghostty/config
  ~/.config/ghostty/themes
  ~/.config/herdr/config.toml
  ~/.config/herdr/nvim-ai-bridge.sh
  ~/.config/nvim
  ~/.config/wezterm
  ~/.config/mcphub
  ~/.pi/agent/extensions
  ~/.pi/agent/git/.gitignore
  ~/.pi/agent/npm/.gitignore
  ~/.pi/agent/powerline.json
  ~/.pi/agent/settings.json
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

# pi-fff: always replace built-in grep/find with FFF
export PI_FFF_MODE=override

unalias claudex 2>/dev/null
function claudex {
  local proxy_key
  proxy_key=$(awk '/^api-keys:/{getline; gsub(/^[[:space:]]*-[[:space:]]*"|"[[:space:]]*$/, ""); print; exit}' \
    "$HOME/.cli-proxy-api/config.yaml")

  if [[ -z "$proxy_key" ]]; then
    print -u2 "claudex: no API key found in ~/.cli-proxy-api/config.yaml"
    return 1
  fi

  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
    ANTHROPIC_AUTH_TOKEN="$proxy_key" \
    CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol \
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 \
    ENABLE_TOOL_SEARCH=false \
    claude --dangerously-skip-permissions --model gpt-5.6-sol "$@"
}
