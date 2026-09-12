#!/bin/bash
# Two-way alt+a bridge between Neovim and coding-agent panes inside herdr.
# Bound in config.toml as a [[keys.command]] direct chord with type = "shell",
# so it runs detached with no HERDR_* pane context: the UI-focused pane
# (herdr pane current with no target) tells us where the chord fired.
#
#  - Focused pane runs Neovim: hand the whole flow to Neovim over the
#    workspace-scoped socket; its Lua builds the (mode-aware) reference,
#    picks the agent, and delivers via `herdr pane send-text`.
#  - Anything else: ask the workspace's Neovim for its open file and insert
#    "@/abs/path " into the focused pane without submitting.
set -uo pipefail

HERDR_BIN=${HERDR_BIN:-$(command -v herdr || echo "$HOME/.local/bin/herdr")}
NVIM_BIN=${NVIM_BIN:-$(command -v nvim || echo /opt/homebrew/bin/nvim)}
JQ_BIN=${JQ_BIN:-$(command -v jq || echo /usr/bin/jq)}

notify() {
  local title=$1 body=${2:-}
  if [[ -n "$body" ]]; then
    "$HERDR_BIN" notification show "$title" --body "$body" >/dev/null 2>&1 || true
  else
    "$HERDR_BIN" notification show "$title" >/dev/null 2>&1 || true
  fi
}

current=$("$HERDR_BIN" pane current 2>/dev/null) || exit 0
pane_id=$("$JQ_BIN" -r '.result.pane.pane_id // empty' <<<"$current")
workspace_id=$("$JQ_BIN" -r '.result.pane.workspace_id // empty' <<<"$current")
[[ -n "$pane_id" && -n "$workspace_id" ]] || exit 0

socket="/tmp/nvim-herdr-${workspace_id//[^[:alnum:]_.-]/_}.sock"
if [[ ! -S "$socket" ]]; then
  notify "alt+a" "No Neovim socket for workspace $workspace_id"
  exit 0
fi

focused_pane_is_nvim() {
  "$HERDR_BIN" pane process-info --pane "$pane_id" 2>/dev/null \
    | "$JQ_BIN" -e '[.result.process_info.foreground_processes[]?.name // empty]
                    | map(select(test("^n?vim$"))) | length > 0' >/dev/null 2>&1
}

if focused_pane_is_nvim; then
  "$NVIM_BIN" --server "$socket" --remote-expr \
    'v:lua.require("utils.herdr").send_current_reference()' >/dev/null 2>&1 \
    || notify "alt+a" "Neovim did not answer on $socket"
  exit 0
fi

ref=$("$NVIM_BIN" --server "$socket" --remote-expr \
  'v:lua.require("utils.herdr").file_reference()' 2>/dev/null | tr -d '\r')
ref=${ref%%$'\n'*}
if [[ "$ref" != @* ]]; then
  notify "alt+a" "No file open in workspace Neovim"
  exit 0
fi

"$HERDR_BIN" pane send-text "$pane_id" "$ref " >/dev/null 2>&1 \
  || notify "alt+a" "send-text failed for pane $pane_id"
