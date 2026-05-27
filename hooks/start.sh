#!/usr/bin/env bash
# SessionStart hook — launch Claudemeter if not already running
STDIN_DATA=$(cat)
SESSION_ID=$(echo "$STDIN_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

mkdir -p /tmp/claudemeter-sessions
[ -n "$SESSION_ID" ] && touch "/tmp/claudemeter-sessions/$SESSION_ID"

pgrep -qf "python.*claudemeter\.py" && exit 0
nohup "$(dirname "$0")/../run.sh" < /dev/null >> /tmp/claudemeter.log 2>&1 &
