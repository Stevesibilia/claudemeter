## Context

Claudemeter is a single-file Python app that polls Anthropic's rate-limit headers every 60s using an OAuth token. Currently macOS-only (rumps menu bar + Keychain). Claude Code has a `statusLine` setting (`~/.claude/settings.json`) that executes a command and displays its stdout in the terminal footer — this is the mechanism caveman uses for its `[CAVEMAN]` badge.

The team wants quota info visible inside Claude Code on both macOS and Linux without requiring macOS-specific dependencies on Linux.

## Goals / Non-Goals

**Goals:**
- Quota visible in Claude Code statusline on both macOS and Linux
- Single codebase, platform differences isolated to token retrieval and optional GUI deps
- Headless poller works with zero GUI dependencies (just `httpx` or stdlib)
- macOS menu bar continues to work as before (optional, additive)
- Cache file is the single interface between poller and statusline display
- Statusline script is fast (<50ms), no Python startup, no network calls

**Non-Goals:**
- Linux system tray / desktop integration
- Windows support
- Real-time updates (every-second refresh) — 60s polling is fine
- Replacing the macOS menu bar with statusline-only

## Decisions

### 1. JSON cache file at `~/.claude/.claudemeter-quota`

Format:
```json
{"s":47,"w":12,"sr":142,"wr":4320,"st":"normal","ts":1748350000}
```

Fields: `s`=5h%, `w`=7d%, `sr`=5h reset minutes, `wr`=7d reset minutes, `st`=status string, `ts`=unix timestamp of last poll.

Why JSON: structured, extensible, the statusline script can do staleness checks via `ts`. Why `~/.claude/`: colocated with Claude Code config, same dir caveman uses for its flag files.

Alternative: pre-formatted text file (just `cat` it). Rejected — no staleness detection, no flexibility for different display formats.

### 2. `--headless` flag on `claudemeter.py`

When `--headless` is passed:
- Skip importing `rumps`/`AppKit`
- Run poller loop in foreground (no menu bar)
- Write cache file every cycle
- Exit cleanly on SIGTERM/SIGINT

When run without flag (or `--menubar`):
- Current behavior + also writes cache file as side effect

This keeps one script, no code duplication. Platform-specific deps gated behind import.

Alternative: separate `claudemeter-poller.py`. Rejected — duplicates poll logic, two files to maintain.

### 3. Bash statusline script with staleness detection

```bash
# Read JSON, format, handle stale/missing
```

If cache file is missing → output nothing (Claude Code shows empty statusline).
If cache is older than 120s → append `?` indicator (stale data).
ANSI orange color (same as Claude orange: `\033[38;5;172m`).

No Python in the statusline path — must be instant since Claude Code calls it frequently.

### 4. Platform-aware token resolution

Priority order:
1. macOS Keychain (`security find-generic-password`) — if `security` binary exists
2. Credentials file (`~/.claude/.credentials.json`) — cross-platform fallback

Both paths already exist in `claudemeter.py`. Just need to make Keychain gracefully skip on Linux (already does via `FileNotFoundError` catch).

### 5. Split requirements

- `requirements.txt` — base: `httpx>=0.27.0` only
- `requirements-macos.txt` — adds `rumps>=0.4.0`, `pyobjc-framework-Cocoa>=10.0`

Installer detects platform and installs appropriate set.

### 6. Installer wires statusLine into settings.json

Same approach as hook registration: Python script merges `statusLine` key into `~/.claude/settings.json`. Idempotent — skips if already present.

## Risks / Trade-offs

- [Statusline refresh frequency unknown] → Claude Code docs don't specify how often it calls the command. If it's every keystroke, the bash script must stay extremely fast. Reading a small JSON file + printf is safe.
- [Cache file race condition] → Poller writes, statusline reads. Mitigated: atomic write (write to temp, rename). JSON is small enough that partial reads are unlikely but rename makes it safe.
- [Stale display after poller crashes] → Staleness indicator (`?`) covers this. User sees stale marker and knows to investigate.
- [Token refresh on Linux] → Claude Code may refresh tokens in `.credentials.json` without notice. Poller re-reads on 401, same as current Keychain retry logic.
