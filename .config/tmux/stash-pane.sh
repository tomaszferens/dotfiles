#!/bin/bash
# Find the _hidden window by matching name, get its exact index
hidden_id=$(tmux list-windows -F '#{window_id}:#{window_name}' 2>/dev/null | grep ':_hidden$' | head -1 | cut -d: -f1)

if [ -n "$hidden_id" ]; then
  tmux join-pane -d -s "{bottom}" -t "$hidden_id"
else
  tmux break-pane -d -s "{bottom}" -n _hidden
fi
