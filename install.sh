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
    python3 - "$SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)

# Match any claudemeter hook regardless of install dir (default or dev repo).
def is_claudemeter(h):
    return isinstance(h, dict) and "claudemeter" in h.get("command", "")

hooks = cfg.get("hooks", {})
for section in ["SessionStart", "SessionEnd", "Stop"]:
    entries = hooks.get(section, [])
    cleaned = []
    for e in entries:
        if isinstance(e, dict):
            inner = [h for h in e.get("hooks", []) if not is_claudemeter(h)]
            if inner:
                cleaned.append({**e, "hooks": inner})
        else:
            cleaned.append(e)
    if cleaned:
        hooks[section] = cleaned
    elif section in hooks:
        del hooks[section]

# Remove statusLine if it points to claudemeter
sl = cfg.get("statusLine", {})
if isinstance(sl, dict) and "claudemeter" in sl.get("command", ""):
    del cfg["statusLine"]

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
    changed "hooks and statusLine removed from $SETTINGS"
  fi

  # Kill running process
  pkill -f "python.*claudemeter\.py" 2>/dev/null && changed "stopped running process" || true

  # Remove KDE plasmoid
  if command -v plasmashell >/dev/null 2>&1 && kpackagetool6 --type Plasma/Applet --show org.kde.claudemeter >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove org.kde.claudemeter 2>/dev/null && changed "plasmoid removed" || true
  fi

  # Remove cache file
  rm -f "$HOME/.claude/.claudemeter-quota"

  # Remove install directory
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    changed "removed $INSTALL_DIR"
  fi

  # Waybar cleanup hint
  if [ "$PLATFORM" != "Darwin" ] && command -v waybar >/dev/null 2>&1; then
    WAYBAR_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config"
    [ ! -f "$WAYBAR_CFG" ] && WAYBAR_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc"
    if [ -f "$WAYBAR_CFG" ] && grep -q "claudemeter" "$WAYBAR_CFG" 2>/dev/null; then
      echo ""
      echo "NOTE: Remove 'custom/claudemeter' from your Waybar config manually:"
      echo "  $WAYBAR_CFG"
      echo "Also remove #custom-claudemeter styles from your Waybar style.css."
      echo ""
    fi
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
  [ -f "$INSTALL_DIR/claudemeter-waybar.sh" ] && chmod +x "$INSTALL_DIR/claudemeter-waybar.sh"
  changed "updated to $CLAUDEMETER_VERSION"
fi

# --- Venv + deps ----------------------------------------------------------
if [ "$PLATFORM" = "Darwin" ] && [ -f "$INSTALL_DIR/requirements-macos.txt" ]; then
  REQS_FILE="$INSTALL_DIR/requirements-macos.txt"
elif [ -f "$INSTALL_DIR/requirements-base.txt" ]; then
  REQS_FILE="$INSTALL_DIR/requirements-base.txt"
else
  REQS_FILE="$INSTALL_DIR/requirements.txt"
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

# --- KDE Plasma widget -----------------------------------------------------
if [ "$PLATFORM" != "Darwin" ] && command -v plasmashell >/dev/null 2>&1; then
  PLASMOID_DIR="$INSTALL_DIR/kde-plasmoid"
  if [ -d "$PLASMOID_DIR" ]; then
    if kpackagetool6 --type Plasma/Applet --show org.kde.claudemeter >/dev/null 2>&1; then
      # Compare installed version with source to avoid false CHANGED
      INSTALLED_VER=$(python3 -c "import json; print(json.load(open('$HOME/.local/share/plasma/plasmoids/org.kde.claudemeter/metadata.json'))['KPlugin']['Version'])" 2>/dev/null || echo "")
      SOURCE_VER=$(python3 -c "import json; print(json.load(open('$PLASMOID_DIR/metadata.json'))['KPlugin']['Version'])" 2>/dev/null || echo "")
      if [ "$INSTALLED_VER" != "$SOURCE_VER" ]; then
        kpackagetool6 --type Plasma/Applet --upgrade "$PLASMOID_DIR" 2>/dev/null && changed "plasmoid upgraded to $SOURCE_VER"
      fi
    else
      kpackagetool6 --type Plasma/Applet --install "$PLASMOID_DIR" && changed "plasmoid installed"
      echo ""
      echo "KDE Plasma widget installed! To add it to your panel:"
      echo "  1. Right-click your panel → Add Widgets"
      echo "  2. Search for \"Claudemeter\""
      echo "  3. Drag it to your panel"
      echo ""
    fi
  fi
fi

# --- Waybar hint (Sway / Hyprland) ----------------------------------------
if [ "$PLATFORM" != "Darwin" ] && command -v waybar >/dev/null 2>&1; then
  WAYBAR_SCRIPT="$INSTALL_DIR/claudemeter-waybar.sh"
  if [ -f "$WAYBAR_SCRIPT" ]; then
    echo ""
    echo "Waybar detected! To add Claudemeter to your bar:"
    echo ""
    echo "  1. Add to ~/.config/waybar/config:"
    echo '     "modules-right": ["custom/claudemeter", ...]'
    echo ""
    echo '     "custom/claudemeter": {'
    echo "         \"exec\": \"$WAYBAR_SCRIPT\","
    echo '         "return-type": "json",'
    echo '         "interval": 30,'
    echo '         "tooltip": true'
    echo '     }'
    echo ""
    echo "  2. Add styles from: $INSTALL_DIR/waybar/style.css"
    echo "  3. Reload: killall -SIGUSR2 waybar"
    echo ""
  fi
fi

# --- Result ---------------------------------------------------------------
if [ "$CHANGED" -eq 0 ]; then
  echo "OK: already up to date"
fi
exit 0
