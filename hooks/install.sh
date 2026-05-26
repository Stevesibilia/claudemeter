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
    entries = hooks.setdefault(section, [])
    # Avoid duplicates
    for e in entries:
        if isinstance(e, dict) and e.get("command") == cmd:
            return
    entries.append({"type": "command", "command": cmd})

add_hook("SessionStart", start_cmd)
add_hook("Stop", stop_cmd)

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"Hooks registered in {path}")
EOF
