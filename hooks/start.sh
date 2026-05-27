#!/usr/bin/env bash
# SessionStart hook — launch Claudemeter if not already running
STDIN_DATA=$(cat)
SESSION_ID=$(echo "$STDIN_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

mkdir -p /tmp/claudemeter-sessions
[ -n "$SESSION_ID" ] && touch "/tmp/claudemeter-sessions/$SESSION_ID"

pgrep -qf "python.*claudemeter\.py" && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = "Darwin" ]; then
  nohup "$SCRIPT_DIR/run.sh" < /dev/null >> /tmp/claudemeter.log 2>&1 &
else
  nohup "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/claudemeter.py" --headless < /dev/null >> /tmp/claudemeter.log 2>&1 &
fi
