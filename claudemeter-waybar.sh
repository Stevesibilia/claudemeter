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

# Read cache and produce Waybar JSON entirely in Python to avoid
# shell interpolation issues with JSON escaping. The cache fields
# sr/wr are in minutes (see claudemeter.py reset_minutes()).
python3 - "$CACHE" <<'PYEOF'
import json, sys, time

cache_path = sys.argv[1]
try:
    with open(cache_path) as f:
        d = json.load(f)
except Exception:
    sys.exit(0)

s = int(d.get("s", 0))
w = int(d.get("w", 0))
sr = int(d.get("sr", 0))   # reset in minutes
wr = int(d.get("wr", 0))   # reset in minutes
st = str(d.get("st", "unknown"))
ts = int(d.get("ts", 0))

# Staleness check
age = int(time.time()) - ts
stale = age > 120

# Glyph based on 5h utilization
if s < 50:
    glyph = "◔"
elif s < 75:
    glyph = "◑"
elif s < 95:
    glyph = "◕"
else:
    glyph = "●"

# CSS class — st values from Anthropic headers: allowed, allow_warning, blocked, etc.
# Treat anything starting with "allow" as healthy; anything else is error.
if not st.startswith("allow") or stale:
    css_class = "error"
elif s >= 95:
    css_class = "critical"
elif s >= 75:
    css_class = "warning"
else:
    css_class = "normal"

# Format reset countdown (input is minutes)
def fmt_reset(mins):
    if mins <= 0:
        return "now"
    d = mins // (60 * 24)
    h = (mins % (60 * 24)) // 60
    m = mins % 60
    if d > 0:
        return f"{d}d {h}h {m}m"
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"

reset_5h = fmt_reset(sr)
reset_7d = fmt_reset(wr)

# Build text
stale_suffix = " ?" if stale else ""
text = f"{glyph} 5h:{s}% 7d:{w}%{stale_suffix}"

# Build tooltip
lines = [
    "Claude Code Quota",
    "━━━━━━━━━━━━━━━━",
    f"5h: {s}% (resets in {reset_5h})",
    f"7d: {w}% (resets in {reset_7d})",
    f"Status: {st}",
]
if stale:
    lines.append(f"⚠ Data is stale ({age}s old)")
tooltip = "\n".join(lines)

# Output valid JSON via json.dumps (handles escaping)
print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))
PYEOF
