#!/usr/bin/env zsh
set -u

SESSION="aurum_finance"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DIR="${DIR:-$SCRIPT_DIR}"
MIX_PORT="${MIX_PORT:-4000}"
TIDEWAVE_PORT="${TIDEWAVE_PORT:-4001}"

cd "$DIR" || {
  echo "ERROR: failed to cd to $DIR"
  exit 1
}

COLS=$(tput cols 2>/dev/null || echo 160)
LINES=$(tput lines 2>/dev/null || echo 45)

inside_tmux() { [[ -n "${TMUX-}" ]]; }

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n main -c "$DIR" -x "$COLS" -y "$LINES"

  # Top 20% split into two panes, bottom 80% for server
  tmux split-window -v -p 80 -t "$SESSION:main"
  tmux select-window -t "$SESSION:main"
  tmux select-pane -U
  tmux split-window -h -p 50

  # Bottom pane: Phoenix server
  tmux select-window -t "$SESSION:main"
  tmux select-pane -D
  tmux send-keys "mix phx.server" C-m

  # Top-left pane: shell for mix tasks
  tmux select-pane -U
  tmux select-pane -L
  tmux send-keys "TIDEWAVE_PORT=${TIDEWAVE_PORT} mix tidewave" C-m

  # Top-right pane: interactive iex
  tmux select-pane -R
  tmux send-keys "iex -S mix" C-m

  tmux new-window -t "$SESSION" -n dev -c "$DIR"
  tmux new-window -t "$SESSION" -n llm -c "$DIR"
fi

if inside_tmux; then
  tmux switch-client -t "$SESSION" || {
    echo "ERROR: tmux switch-client failed"
    zsh
  }
else
  tmux attach -t "$SESSION" || {
    echo "ERROR: tmux attach failed"
    zsh
  }
fi
