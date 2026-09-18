#!/bin/bash
hidden_id=$(tmux list-windows -F '#{window_id}:#{window_name}' 2>/dev/null | grep ':_hidden$' | head -1 | cut -d: -f1)

if [ -z "$hidden_id" ]; then
  tmux display-message "No hidden panes"
  exit 0
fi

# Send current bottom to the END of _hidden
tmux join-pane -d -s "{bottom}" -t "$hidden_id"
# Pull the FIRST pane from _hidden to bottom
tmux join-pane -v -s "${hidden_id}.0" -l 30%
tmux select-pane -t "{top}"
