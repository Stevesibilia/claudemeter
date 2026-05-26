#!/usr/bin/env bash
# Registers Claudemeter hooks in ~/.claude/settings.json
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
START_CMD="$REPO_DIR/hooks/start.sh"
STOP_CMD="$REPO_DIR/hooks/stop.sh"

chmod +x "$REPO_DIR/hooks/start.sh" "$REPO_DIR/hooks/stop.sh"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Use python3 to safely merge — avoids jq dependency
python3 - "$SETTINGS" "$START_CMD" "$STOP_CMD" <<'EOF'
import json, sys

path, start_cmd, stop_cmd = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)

hooks = cfg.setdefault("hooks", {})

def add_hook(section, cmd):
    # Claude Code format: [{matcher, hooks: [{type, command}]}]
    entries = hooks.setdefault(section, [])
    # Remove stale entries for this command (may lack timeout), then re-add
    for e in entries[:]:
        if isinstance(e, dict):
            e["hooks"] = [h for h in e.get("hooks", []) if not (isinstance(h, dict) and h.get("command") == cmd)]
        if not e.get("hooks"):
            entries.remove(e)
    entries.append({"hooks": [{"type": "command", "command": cmd, "timeout": 5}]})

add_hook("SessionStart", start_cmd)
add_hook("SessionEnd", stop_cmd)

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"Hooks registered in {path}")
EOF
