#!/bin/bash
set -euo pipefail

TMUX_BIN=${TMUX_BIN:-tmux}
WEZTERM_BIN=${WEZTERM_BIN:-wezterm}
NVIM_BIN=${NVIM_BIN:-$(command -v nvim || true)}
MODE=${1:---meta-a}

active_pane=""
active_command=""

load_active_tmux_context() {
  active_pane="$($TMUX_BIN display-message -p '#{pane_id}' 2>/dev/null || true)"
  active_command="$($TMUX_BIN display-message -p '#{pane_current_command}' 2>/dev/null || true)"
}

is_nvim_command() {
  case "$(basename "${1:-}")" in
    nvim | vim) return 0 ;;
    *) return 1 ;;
  esac
}

socket_for_id() {
  local pane_id=${1//[^[:alnum:]_.-]/_}
  printf '/tmp/nvim-wezterm-%s.sock' "$pane_id"
}

query_socket_reference() {
  local socket=$1
  local file

  [[ -n "$NVIM_BIN" && -S "$socket" ]] || return 1

  file="$($NVIM_BIN --server "$socket" --remote-expr "expand('%:.')" 2>&1 | sed 's/[[:space:]]*$//' || true)"
  if [[ -z "$file" || "$file" =~ ^E[0-9]+: ]]; then
    return 1
  fi

  printf '@%s\n' "$file"
}

find_tmux_nvim_pane_ids() {
  command -v "$TMUX_BIN" >/dev/null 2>&1 || return 0

  {
    $TMUX_BIN list-panes -F '#{pane_id}	#{pane_current_command}' 2>/dev/null || true
    $TMUX_BIN list-panes -a -F '#{pane_id}	#{pane_current_command}' 2>/dev/null || true
  } | awk -F '\t' -v active="$active_pane" '
    $1 != "" && $1 != active && ($2 == "nvim" || $2 == "vim") && !seen[$1]++ { print $1 }
  '
}

find_wezterm_nvim_pane_ids() {
  command -v "$WEZTERM_BIN" >/dev/null 2>&1 || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  $WEZTERM_BIN cli list --format json 2>/dev/null | python3 -c '
import json, re, sys
try:
    panes = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for pane in panes:
    title = str(pane.get("title") or "")
    # Direct Neovim panes usually expose "nvim" as the WezTerm title.  tmux
    # panes are handled via tmux pane ids/sockets above; stale candidates are
    # harmless because the socket query below must succeed.
    if re.search(r"(^|[^A-Za-z0-9_])(n?vim|vim)([^A-Za-z0-9_]|$)", title, re.I):
        pane_id = pane.get("pane_id")
        if pane_id is not None:
            print(pane_id)
'
}

current_file_reference() {
  local pane_id socket ref

  if [[ -z "$NVIM_BIN" ]]; then
    $TMUX_BIN display-message 'nvim not found in PATH' 2>/dev/null || true
    return 1
  fi

  while IFS= read -r pane_id; do
    [[ -n "$pane_id" ]] || continue
    socket=$(socket_for_id "$pane_id")
    if ref=$(query_socket_reference "$socket"); then
      printf '%s\n' "$ref"
      return 0
    fi
  done < <(find_tmux_nvim_pane_ids)

  while IFS= read -r pane_id; do
    [[ -n "$pane_id" ]] || continue
    socket=$(socket_for_id "$pane_id")
    if ref=$(query_socket_reference "$socket"); then
      printf '%s\n' "$ref"
      return 0
    fi
  done < <(find_wezterm_nvim_pane_ids)

  # Last resort: direct/tmux Neovim instances publish per-pane sockets here.
  # This covers Neovim in another WezTerm tab or another tmux session/server.
  for socket in /tmp/nvim-wezterm-*.sock; do
    [[ -S "$socket" ]] || continue
    if ref=$(query_socket_reference "$socket"); then
      printf '%s\n' "$ref"
      return 0
    fi
  done

  $TMUX_BIN display-message 'M-a: no reachable nvim server found' 2>/dev/null || true
  return 1
}

send_text() {
  local target=$1
  local text=$2
  local chunk

  while [[ "$text" == *$'\n'* ]]; do
    chunk=${text%%$'\n'*}
    if [[ -n "$chunk" ]]; then
      $TMUX_BIN send-keys -t "$target" -l "$chunk"
    fi
    $TMUX_BIN send-keys -t "$target" Enter
    text=${text#*$'\n'}
  done

  if [[ -n "$text" ]]; then
    $TMUX_BIN send-keys -t "$target" -l "$text"
  fi
}

send_reference_to_active_tmux_pane() {
  local ref
  ref=$(current_file_reference) || return 0
  send_text "$active_pane" "$ref "
}

case "$MODE" in
  --print-ref)
    current_file_reference
    ;;
  --meta-a)
    load_active_tmux_context
    if [[ -z "$active_pane" ]]; then
      exit 0
    fi
    if is_nvim_command "$active_command"; then
      $TMUX_BIN send-keys -t "$active_pane" M-a
    else
      send_reference_to_active_tmux_pane
    fi
    ;;
  *)
    $TMUX_BIN display-message "Unknown nvim-ai-reference mode: $MODE" 2>/dev/null || true
    exit 1
    ;;
esac
