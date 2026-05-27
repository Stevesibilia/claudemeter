#!/bin/bash
# claudemeter-statusline.sh — Claude Code statusline badge
# Reads cached quota data and outputs ANSI-colored status text.
#
# Usage in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash /path/to/claudemeter-statusline.sh" }
#
# Outputs nothing if cache is missing (claudemeter not running).
# Appends ? if data is stale (>120s old).

CACHE="${HOME}/.claude/.claudemeter-quota"

# Missing file — output nothing
[ ! -f "$CACHE" ] && exit 0

# Refuse symlinks
[ -L "$CACHE" ] && exit 0

# Read cache (small file, single line of JSON)
DATA=$(cat "$CACHE" 2>/dev/null)
[ -z "$DATA" ] && exit 0

# Extract fields — use parameter expansion to avoid external deps
# Python one-liner is fast enough (~15ms) and handles JSON safely
read -r S W TS <<< $(printf '%s' "$DATA" | python3 -c "
import sys, json, time
try:
    d = json.load(sys.stdin)
    print(d.get('s', 0), d.get('w', 0), d.get('ts', 0))
except:
    print('0 0 0')
" 2>/dev/null)

# Fallback if python3 failed
[ -z "$S" ] && exit 0

# Staleness check
NOW=$(date +%s)
AGE=$((NOW - TS))
STALE=""
if [ "$AGE" -gt 120 ]; then
  STALE=" ?"
fi

# Glyph based on 5h utilization
if [ "$S" -lt 50 ]; then
  GLYPH="◔"
elif [ "$S" -lt 75 ]; then
  GLYPH="◑"
elif [ "$S" -lt 95 ]; then
  GLYPH="◕"
else
  GLYPH="●"
fi

# Output with ANSI orange (color 172)
printf '\033[38;5;172m%s 5h:%d%% 7d:%d%%%s\033[0m' "$GLYPH" "$S" "$W" "$STALE"
