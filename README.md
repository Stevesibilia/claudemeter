# Claudemeter

Cross-platform Claude Code quota monitor. Shows your unified **5-hour** and **7-day** quota utilization in real time.

- **macOS**: Menu bar indicator (Claude orange) + Claude Code statusline
- **Linux**: Claude Code statusline + Waybar module (Sway / Hyprland)

## What it shows

### Claude Code statusline (macOS + Linux)

The Claude Code terminal footer displays:

```
◔ 5h:47% 7d:12%
```

A `?` suffix appears if data is stale (poller not running or crashed).

### macOS menu bar (macOS only)

The menu bar title looks like:

```
◔ 5h 47% · 7d 12%
```

Glyph reflects 5h utilization:

| Glyph | Range    |
| ----- | -------- |
| ◔     | < 50 %   |
| ◑     | 50–74 %  |
| ◕     | 75–94 %  |
| ●     | ≥ 95 %   |
| ⚠     | error    |

Click the icon to see:

- 5h utilization + reset countdown
- 7d utilization + reset countdown
- Rate-limit status
- Manual refresh

### Waybar module (Sway / Hyprland)

For Sway and Hyprland users, Claudemeter provides a Waybar custom module that displays quota in the bar with a rich tooltip:

```
◔ 5h:47% 7d:12%
```

Hover for a detailed tooltip with reset countdowns and status. The module uses CSS classes for color-coded states:

| Class      | Condition              | Color          |
| ---------- | ---------------------- | -------------- |
| `normal`   | < 75 %, status=allow   | Claude orange  |
| `warning`  | 75–94 %                | Orange         |
| `critical` | ≥ 95 %                 | Red (blinking) |
| `error`    | stale / blocked / error | Gray          |

#### Quick setup

1. Install Claudemeter (the installer detects Waybar automatically):

```bash
curl -fsSL https://raw.githubusercontent.com/Stevesibilia/claudemeter/main/install.sh | bash
```

2. Add the module to your Waybar config (`~/.config/waybar/config`):

```json
"modules-right": ["custom/claudemeter", "clock", "..."],

"custom/claudemeter": {
    "exec": "~/.local/share/claudemeter/claudemeter-waybar.sh",
    "return-type": "json",
    "interval": 30,
    "tooltip": true
}
```

3. Add styles to `~/.config/waybar/style.css` (see [`waybar/style.css`](waybar/style.css) for a ready-made snippet).

4. Reload Waybar: `killall -SIGUSR2 waybar`

## How it works

Claudemeter reads the OAuth access token from the macOS Keychain (`Claude Code-credentials`) or from `~/.claude/.credentials.json` (Linux), then sends a 1-token `POST /v1/messages` to `api.anthropic.com` once per minute. Anthropic's response carries the rate-limit headers:

- `anthropic-ratelimit-unified-5h-utilization`
- `anthropic-ratelimit-unified-5h-reset`
- `anthropic-ratelimit-unified-7d-utilization`
- `anthropic-ratelimit-unified-7d-reset`
- `anthropic-ratelimit-unified-5h-status`

These drive the menu bar display.

Poll results are also written to `~/.claude/.claudemeter-quota` (JSON) which the Claude Code statusline script reads.

> Cost: each poll consumes `max_tokens=1` (one "hi"). Negligible, but real.

## Requirements

- macOS 12+ or Linux
- Python 3.10+
- You must be logged in to Claude Code

## Modes

| Mode | Platform | What |
|------|----------|------|
| Menu bar | macOS | Full menu bar app + statusline cache |
| Headless (`--headless`) | macOS + Linux | Background poller, writes cache only |
| Waybar module | Linux (Sway / Hyprland) | Reads cache, outputs Waybar JSON |

On Linux, the installer automatically uses headless mode. The Claude Code statusline reads the cache file on both platforms.

## Install & run

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Stevesibilia/claudemeter/main/install.sh | bash
```

This downloads Claudemeter to `~/.local/share/claudemeter`, creates a venv, installs dependencies, and registers Claude Code hooks — all idempotently.

Pin a specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/Stevesibilia/claudemeter/main/install.sh | CLAUDEMETER_VERSION=v1.0.0 bash
```

Custom install location:

```bash
curl -fsSL ... | INSTALL_DIR=/opt/claudemeter bash
```

Uninstall:

```bash
~/.local/share/claudemeter/install.sh --uninstall
```

### From source (development)

```bash
git clone https://github.com/Stevesibilia/claudemeter.git
cd claudemeter
./run.sh
```

`run.sh` creates a `.venv`, installs dependencies, and starts the app.

### Ansible

The installer is fully idempotent and outputs machine-readable status:

```yaml
- name: Install/update claudemeter
  ansible.builtin.shell: |
    curl -fsSL https://raw.githubusercontent.com/Stevesibilia/claudemeter/{{ claudemeter_version }}/install.sh \
    | CLAUDEMETER_VERSION={{ claudemeter_version }} bash
  register: result
  changed_when: "'CHANGED' in result.stdout"

- name: Uninstall claudemeter
  ansible.builtin.shell: ~/.local/share/claudemeter/install.sh --uninstall
  when: claudemeter_state == "absent"
```

Output protocol:
- `CHANGED: <description>` — printed for each mutation
- `OK: already up to date` — when nothing changed
- Exit 0 = success, exit 1 = error

Verify your Keychain entry first:

```bash
security find-generic-password -s "Claude Code-credentials" -a "$USER" -w | head -c 20
```

## Auto-launch with Claude Code (hooks)

Claudemeter can start automatically when you open Claude Code and stop when you close the last session.

```bash
./hooks/install.sh
```

This registers two hooks in `~/.claude/settings.json`:

| Hook | Action |
|------|--------|
| `SessionStart` | Launches Claudemeter if not already running |
| `SessionEnd` | Kills Claudemeter only when the **last** Claude session closes |

Multiple Claude windows are safe — the stop hook counts running sessions before killing.

Logs land in `/tmp/claudemeter.log`.

To uninstall:

```bash
./hooks/uninstall.sh
```

Removes both hooks from `~/.claude/settings.json` and stops Claudemeter.

## Run on login (optional)

Drop a launchd plist in `~/Library/LaunchAgents/`. Example template:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.claudemeter</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOU/Homelab/Tools/claudemeter/run.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/claudemeter.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/claudemeter.err.log</string>
</dict>
</plist>
```

Load: `launchctl load ~/Library/LaunchAgents/local.claudemeter.plist`

## Known limitations

- **Single statusline**: Claude Code supports only one `statusLine` command. If you use another plugin that sets a statusline (e.g., caveman), only one can be active. A combined wrapper script is needed to show both — not yet automated.
- **Token refresh**: Claudemeter reads the stored token but does not refresh it. If the token expires between sessions, re-login to Claude Code to get a fresh one.

## Credits

Inspired by **[Clawdmeter](https://github.com/HermannBjorgvin/Clawdmeter)** by [Hermann Björgvin](https://github.com/HermannBjorgvin) — an ESP32 desk dashboard for Claude Code usage. Claudemeter reuses the same approach for reading the OAuth token from the macOS Keychain and parsing Anthropic's unified rate-limit headers, but drops the BLE/ESP32 transport in favor of a native macOS menu bar widget (rumps + PyObjC).

If you want a physical desk indicator, check Clawdmeter — it is excellent.

## License

MIT — see [LICENSE](LICENSE).
