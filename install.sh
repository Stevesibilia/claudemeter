#!/usr/bin/env bash
# Claudemeter installer — idempotent install/update/uninstall.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Stevesibilia/claudemeter/main/install.sh | bash
#   curl -fsSL ... | CLAUDEMETER_VERSION=v1.0.0 bash
#   INSTALL_DIR=/custom/path ./install.sh
#   ./install.sh --uninstall
#
# Environment variables:
#   CLAUDEMETER_VERSION  — Version tag to install (default: latest release)
#   INSTALL_DIR          — Installation directory (default: ~/.local/share/claudemeter)
#
# Output protocol (for Ansible integration):
#   CHANGED: <description>  — printed for each mutation
#   OK: already up to date  — printed when nothing changed
#   Exit 0 = success, Exit 1 = error
#
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/claudemeter}"
REPO="Stevesibilia/claudemeter"
PLATFORM="$(uname -s)"  # Darwin or Linux
CHANGED=0

changed() {
  echo "CHANGED: $1"
  CHANGED=1
}

die() {
  echo "ERROR: $1" >&2
  exit 1
}

# --- Uninstall -----------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
  # Remove hooks
  SETTINGS="$HOME/.claude/settings.json"
  if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" "$INSTALL_DIR" <<'PYEOF'
import json, sys

path, install_dir = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)

hooks = cfg.get("hooks", {})
for section in ["SessionStart", "SessionEnd"]:
    entries = hooks.get(section, [])
    cleaned = []
    for e in entries:
        if isinstance(e, dict):
            inner = [h for h in e.get("hooks", [])
                     if not (isinstance(h, dict) and install_dir in h.get("command", ""))]
            if inner:
                cleaned.append({**e, "hooks": inner})
        else:
            cleaned.append(e)
    if cleaned:
        hooks[section] = cleaned
    elif section in hooks:
        del hooks[section]

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
    changed "hooks removed from $SETTINGS"
  fi

  # Kill running process
  pkill -f "python.*claudemeter\.py" 2>/dev/null && changed "stopped running process" || true

  # Remove install directory
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    changed "removed $INSTALL_DIR"
  fi

  echo "Claudemeter uninstalled."
  exit 0
fi

# --- Version resolution ---------------------------------------------------
if [ -z "${CLAUDEMETER_VERSION:-}" ]; then
  CLAUDEMETER_VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null) \
    || die "Failed to fetch latest release. Set CLAUDEMETER_VERSION manually."
fi

# --- Version skip check ---------------------------------------------------
CURRENT_VERSION=""
if [ -f "$INSTALL_DIR/.version" ]; then
  CURRENT_VERSION=$(cat "$INSTALL_DIR/.version")
fi

if [ "$CURRENT_VERSION" = "$CLAUDEMETER_VERSION" ]; then
  # Version matches — check deps hash only
  :
else
  # --- Download + extract -------------------------------------------------
  mkdir -p "$INSTALL_DIR"
  TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$CLAUDEMETER_VERSION.tar.gz"
  curl -fsSL "$TARBALL_URL" | tar xz --strip-components=1 -C "$INSTALL_DIR" \
    || die "Failed to download $TARBALL_URL"
  echo "$CLAUDEMETER_VERSION" > "$INSTALL_DIR/.version"
  chmod +x "$INSTALL_DIR/run.sh" "$INSTALL_DIR/hooks/"*.sh
  changed "updated to $CLAUDEMETER_VERSION"
fi

# --- Venv + deps ----------------------------------------------------------
if [ "$PLATFORM" = "Darwin" ]; then
  REQS_FILE="$INSTALL_DIR/requirements-macos.txt"
else
  REQS_FILE="$INSTALL_DIR/requirements-base.txt"
fi
DEPS_HASH_FILE="$INSTALL_DIR/.venv/.deps-hash"
NEW_HASH=$(shasum -a 256 "$REQS_FILE" | cut -d' ' -f1)
CURRENT_HASH=""
if [ -f "$DEPS_HASH_FILE" ]; then
  CURRENT_HASH=$(cat "$DEPS_HASH_FILE")
fi

if [ "$NEW_HASH" != "$CURRENT_HASH" ]; then
  if [ ! -d "$INSTALL_DIR/.venv" ]; then
    python3 -m venv "$INSTALL_DIR/.venv"
  fi
  "$INSTALL_DIR/.venv/bin/pip" install -U pip -q
  "$INSTALL_DIR/.venv/bin/pip" install -r "$REQS_FILE" -q
  mkdir -p "$(dirname "$DEPS_HASH_FILE")"
  echo "$NEW_HASH" > "$DEPS_HASH_FILE"
  changed "venv rebuilt"
fi

# --- Hooks ----------------------------------------------------------------
SETTINGS="$HOME/.claude/settings.json"
HOOKS_NEEDED=false

if [ ! -f "$SETTINGS" ]; then
  HOOKS_NEEDED=true
else
  # Check if hooks already point to this install dir
  if ! grep -q "$INSTALL_DIR/hooks/start.sh" "$SETTINGS" 2>/dev/null; then
    HOOKS_NEEDED=true
  fi
fi

if [ "$HOOKS_NEEDED" = true ]; then
  INSTALL_DIR="$INSTALL_DIR" "$INSTALL_DIR/hooks/install.sh"
  changed "hooks registered"
fi

# --- StatusLine -----------------------------------------------------------
STATUSLINE_CMD="bash \"$INSTALL_DIR/claudemeter-statusline.sh\""
STATUSLINE_NEEDED=false

if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  echo '{}' > "$SETTINGS"
  STATUSLINE_NEEDED=true
elif ! grep -q "claudemeter-statusline" "$SETTINGS" 2>/dev/null; then
  STATUSLINE_NEEDED=true
fi

if [ "$STATUSLINE_NEEDED" = true ]; then
  python3 - "$SETTINGS" "$STATUSLINE_CMD" <<'PYEOF'
import json, sys

path, cmd = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)

cfg["statusLine"] = {"type": "command", "command": cmd}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
  changed "statusLine registered"
fi

# --- Result ---------------------------------------------------------------
if [ "$CHANGED" -eq 0 ]; then
  echo "OK: already up to date"
fi
exit 0
