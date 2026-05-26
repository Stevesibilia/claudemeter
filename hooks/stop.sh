#!/usr/bin/env bash
# SessionEnd hook — kill Claudemeter only when last Claude Code session closes.
claude_count=$(pgrep -f "claude daemon run --origin transient" 2>/dev/null | wc -l | tr -d ' ')
[ "$claude_count" -gt 1 ] && exit 0
pkill -f "python.*claudemeter\.py" 2>/dev/null || true
