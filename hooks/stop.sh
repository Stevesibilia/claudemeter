#!/usr/bin/env bash
# Stop hook — kill Claudemeter only when last Claude Code session closes.
# Matches the per-session Claude Code CLI daemon, not Claude.app helpers
# or claudemeter itself. At Stop time the closing session daemon is
# still in the process table, so threshold is <=1.
claude_count=$(pgrep -f "claude daemon run --origin transient" 2>/dev/null | wc -l | tr -d ' ')
if [ "$claude_count" -le 1 ]; then
  pkill -f "claudemeter.py" 2>/dev/null || true
fi
