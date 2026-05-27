## Why

Claudemeter currently only works on macOS (menu bar via rumps + AppKit). The team uses Linux too and wants quota visibility inside Claude Code's terminal statusline on both platforms. Claude Code supports a `statusLine` setting that runs a shell command — we can leverage this for a platform-independent display without any macOS-specific dependencies.

## What Changes

- Refactor `claudemeter.py` into two modes: headless poller (cross-platform) and menu bar app (macOS-only)
- The poller writes quota data to a JSON cache file (`~/.claude/.claudemeter-quota`) every poll cycle
- Add `claudemeter-statusline.sh` — a fast bash script that reads the cache and outputs ANSI-colored quota text for Claude Code's statusline
- The installer registers the `statusLine` setting in `~/.claude/settings.json` on both platforms
- On Linux: hooks start the headless poller. On macOS: hooks start the full menu bar app (which also writes the cache)
- macOS menu bar dependencies (`rumps`, `pyobjc`) become optional — not installed on Linux

## Capabilities

### New Capabilities
- `headless-poller`: Background daemon that polls Anthropic API and writes quota to a JSON cache file, cross-platform (macOS + Linux)
- `statusline-display`: Bash script that reads the quota cache and outputs formatted ANSI text for Claude Code's statusLine setting
- `platform-token-resolver`: Unified token retrieval that uses Keychain on macOS and credentials file on Linux

### Modified Capabilities

## Impact

- `claudemeter.py` — major refactor: extract poller logic, add `--headless` mode, write cache file
- `requirements.txt` — split into base (httpx only) and macOS extras (rumps, pyobjc)
- `install.sh` — detect platform, install appropriate deps, register statusLine setting
- `hooks/start.sh` — launch headless poller on Linux, full app on macOS
- `~/.claude/settings.json` — new `statusLine` entry added by installer
- New file: `claudemeter-statusline.sh`
- New file: cache at `~/.claude/.claudemeter-quota` (JSON, written by poller)
