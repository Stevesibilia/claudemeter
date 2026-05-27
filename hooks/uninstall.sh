#!/usr/bin/env bash
# Removes Claudemeter hooks from ~/.claude/settings.json
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
START_CMD="$REPO_DIR/hooks/start.sh"
STOP_CMD="$REPO_DIR/hooks/stop.sh"

if [ ! -f "$SETTINGS" ]; then
  echo "No settings.json found at $SETTINGS — nothing to do."
  exit 0
fi

python3 - "$SETTINGS" "$START_CMD" "$STOP_CMD" <<'EOF'
import json, sys

path, start_cmd, stop_cmd = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)

hooks = cfg.get("hooks", {})

for section, cmd in [("SessionStart", start_cmd), ("SessionEnd", stop_cmd), ("Stop", stop_cmd)]:
    entries = hooks.get(section, [])
    cleaned = []
    for e in entries:
        if isinstance(e, dict):
            inner = [h for h in e.get("hooks", [])
                     if not (isinstance(h, dict) and h.get("command") == cmd)]
            if inner:
                cleaned.append({**e, "hooks": inner})
        else:
            cleaned.append(e)
    hooks[section] = cleaned

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"Hooks removed from {path}")
EOF

pkill -f "claudemeter.py" 2>/dev/null && echo "Claudemeter stopped." || true
