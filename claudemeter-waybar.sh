#!/bin/bash
# claudemeter-waybar.sh — Waybar custom module for Claude Code quota
# Outputs JSON in Waybar's custom module format.
#
# Waybar config (~/.config/waybar/config):
#   "custom/claudemeter": {
#       "exec": "/path/to/claudemeter-waybar.sh",
#       "return-type": "json",
#       "interval": 30,
#       "tooltip": true
#   }
#
# Outputs nothing if cache is missing (claudemeter not running).

CACHE="${HOME}/.claude/.claudemeter-quota"

# Missing or symlinked cache — output nothing
[ ! -f "$CACHE" ] && exit 0
[ -L "$CACHE" ] && exit 0

# Read cache
DATA=$(cat "$CACHE" 2>/dev/null)
[ -z "$DATA" ] && exit 0

# Parse JSON fields
read -r S W SR WR ST TS <<< $(printf '%s' "$DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('s', 0), d.get('w', 0), d.get('sr', 0), d.get('wr', 0), d.get('st', 'unknown'), d.get('ts', 0))
except:
    print('0 0 0 0 unknown 0')
" 2>/dev/null)

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

# CSS class for styling
if [ "$ST" != "normal" ] || [ "$AGE" -gt 120 ]; then
  CLASS="error"
elif [ "$S" -ge 95 ]; then
  CLASS="critical"
elif [ "$S" -ge 75 ]; then
  CLASS="warning"
else
  CLASS="normal"
fi

# Format reset countdowns for tooltip
format_reset() {
  local secs=$1
  if [ "$secs" -le 0 ]; then
    echo "now"
    return
  fi
  local h=$((secs / 3600))
  local m=$(( (secs % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then
    echo "${h}h ${m}m"
  else
    echo "${m}m"
  fi
}

RESET_5H=$(format_reset "$SR")
RESET_7D=$(format_reset "$WR")

# Build tooltip
TOOLTIP="Claude Code Quota\n━━━━━━━━━━━━━━━━\n5h: ${S}% (resets in ${RESET_5H})\n7d: ${W}% (resets in ${RESET_7D})\nStatus: ${ST}"
if [ -n "$STALE" ]; then
  TOOLTIP="${TOOLTIP}\n⚠ Data is stale (${AGE}s old)"
fi

# Waybar JSON output
printf '{"text":"%s 5h:%d%% 7d:%d%%%s","tooltip":"%s","class":"%s"}\n' \
  "$GLYPH" "$S" "$W" "$STALE" "$TOOLTIP" "$CLASS"
