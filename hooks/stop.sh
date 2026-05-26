#!/usr/bin/env bash
# Stop hook — kill Claudemeter only when last Claude session closes.
# At Stop time the closing session is still in the process table,
# so threshold is <=1 (that one process = the session being closed).
claude_count=$(pgrep -c -f "claude" 2>/dev/null || echo 0)
if [ "$claude_count" -le 1 ]; then
  pkill -f "claudemeter.py" 2>/dev/null || true
fi
