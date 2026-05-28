#!/usr/bin/env bash
# SessionEnd hook — kill Claudemeter only when last Claude Code session closes.
STDIN_DATA=$(cat)
SESSION_ID=$(echo "$STDIN_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

[ -n "$SESSION_ID" ] && rm -f "/tmp/claudemeter-sessions/$SESSION_ID"
remaining=$(ls /tmp/claudemeter-sessions/ 2>/dev/null | wc -l | tr -d ' ')

[ "$remaining" -gt 0 ] && exit 0
pkill -f "python.*claudemeter\.py" 2>/dev/null || true
rm -f "$HOME/.claude/.claudemeter-quota"
