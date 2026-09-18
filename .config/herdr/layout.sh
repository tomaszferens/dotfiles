#!/bin/bash
# Rebuild a herdr workspace's tabs from a named profile.
#
#   layout.sh <profile> [--workspace <id>]
#
# Bound in config.toml as [[keys.command]] chords with type = "shell". Herdr
# runs those detached through /bin/sh -lc and hands them the chord's context
# as HERDR_ACTIVE_WORKSPACE_ID / HERDR_ACTIVE_PANE_ID (plus HERDR_BIN_PATH and
# HERDR_SOCKET_PATH). Run by hand, it falls back to the UI-focused pane.
# --workspace overrides the lookup either way.
#
# Idempotent: the profile's tabs are created fresh, then every tab that
# existed before is closed. Closing a tab tears down its pty, which kills the
# shell and whatever was running in it (dev servers, nvim, agents, ...), so
# running it again always ends with exactly the profile's tabs.
#
# Profiles are label|command pairs; an empty command leaves a plain shell.
set -uo pipefail

HERDR_BIN=${HERDR_BIN:-${HERDR_BIN_PATH:-$(command -v herdr || echo "$HOME/.local/bin/herdr")}}
JQ_BIN=${JQ_BIN:-$(command -v jq || echo /usr/bin/jq)}

profile=${1:-}
workspace_id=""
shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace) workspace_id=${2:-}; shift 2 ;;
    *) echo "layout.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

notify() {
  local title=$1 body=${2:-}
  if [[ -n "$body" ]]; then
    "$HERDR_BIN" notification show "$title" --body "$body" >/dev/null 2>&1 || true
  else
    "$HERDR_BIN" notification show "$title" >/dev/null 2>&1 || true
  fi
}

fail() {
  echo "layout.sh: $*" >&2
  notify "layout: $profile" "$*"
  exit 1
}

case $profile in
  sztama)
    tabs=(
      "zsh|"
      "mobile|"
      "dev|"
      "neovim|nvim"
      "LLM|"
    )
    ;;
  generic)
    tabs=(
      "zsh|"
      "nvim|nvim"
      "llm|"
    )
    ;;
  *)
    fail "unknown profile '${profile}' (expected: sztama, generic)"
    ;;
esac

# Resolve the target workspace and the cwd new tabs should start in. A pane's
# `cwd` is its launch directory (the checkout root for project workspaces),
# not the live `foreground_cwd`, so a `cd` in the focused shell does not leak
# into the rebuilt tabs. Without a known pane, the workspace's first pane
# supplies the cwd.
pane_id=""
if [[ -z "$workspace_id" ]]; then
  workspace_id=${HERDR_ACTIVE_WORKSPACE_ID:-}
  pane_id=${HERDR_ACTIVE_PANE_ID:-}
  if [[ -z "$workspace_id" ]]; then
    current=$("$HERDR_BIN" pane current 2>/dev/null) || fail "herdr pane current failed"
    workspace_id=$("$JQ_BIN" -r '.result.pane.workspace_id // empty' <<<"$current")
    pane_id=$("$JQ_BIN" -r '.result.pane.pane_id // empty' <<<"$current")
  fi
fi
[[ -n "$workspace_id" ]] || fail "could not resolve the focused workspace"

panes=$("$HERDR_BIN" pane list --workspace "$workspace_id" 2>/dev/null) \
  || fail "no such workspace: $workspace_id"
cwd=$("$JQ_BIN" -r --arg p "$pane_id" \
  'first((.result.panes[] | select(.pane_id == $p) | .cwd),
         (.result.panes[0].cwd // empty)) // empty' <<<"$panes")
[[ -n "$cwd" ]] || cwd=$HOME

old_tabs=$("$HERDR_BIN" tab list --workspace "$workspace_id" 2>/dev/null \
  | "$JQ_BIN" -r '.result.tabs[].tab_id') || fail "tab list failed for $workspace_id"

# Create the new tabs first so the workspace is never empty (closing its last
# tab would close the workspace itself). They append after the old tabs and
# keep their relative order once the old ones are gone.
first_tab=""
for entry in "${tabs[@]}"; do
  label=${entry%%|*}
  command=${entry#*|}
  created=$("$HERDR_BIN" tab create --workspace "$workspace_id" \
    --cwd "$cwd" --label "$label" --no-focus 2>/dev/null) \
    || fail "tab create failed for '$label'"
  tab_id=$("$JQ_BIN" -r '.result.tab.tab_id // empty' <<<"$created")
  pane_id=$("$JQ_BIN" -r '.result.root_pane.pane_id // empty' <<<"$created")
  [[ -n "$tab_id" && -n "$pane_id" ]] || fail "tab create returned no ids for '$label'"
  [[ -n "$first_tab" ]] || first_tab=$tab_id
  if [[ -n "$command" ]]; then
    # The shell reads typed-ahead input once it reaches its prompt, so this is
    # safe to send immediately after the tab appears.
    "$HERDR_BIN" pane run "$pane_id" "$command" >/dev/null 2>&1 \
      || fail "pane run '$command' failed in $pane_id"
  fi
done

"$HERDR_BIN" tab focus "$first_tab" >/dev/null 2>&1 || true

failed=0
for tab_id in $old_tabs; do
  "$HERDR_BIN" tab close "$tab_id" >/dev/null 2>&1 || failed=$((failed + 1))
done

if (( failed > 0 )); then
  fail "$failed old tab(s) could not be closed in $workspace_id"
fi
