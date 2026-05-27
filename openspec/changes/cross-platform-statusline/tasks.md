## 1. Refactor claudemeter.py for dual-mode operation

- [x] 1.1 Add `--headless` CLI flag parsing (argparse or simple sys.argv check)
- [x] 1.2 Gate `rumps`/`AppKit` imports behind `--headless` check (only import when menu bar mode)
- [x] 1.3 Extract poll loop into standalone function usable by both modes
- [x] 1.4 Add atomic cache file writing after each successful poll (`~/.claude/.claudemeter-quota`)
- [x] 1.5 Add SIGTERM/SIGINT handlers for clean exit in headless mode
- [x] 1.6 Menu bar mode: also write cache file after each poll (call same write function)

## 2. Split dependencies by platform

- [x] 2.1 Create `requirements-base.txt` with `httpx>=0.27.0` only
- [x] 2.2 Create `requirements-macos.txt` that includes base + `rumps>=0.4.0` + `pyobjc-framework-Cocoa>=10.0`
- [x] 2.3 Update `requirements.txt` to be an alias for the appropriate platform file (or remove in favor of installer logic)

## 3. Create statusline script

- [x] 3.1 Write `claudemeter-statusline.sh` — reads JSON cache, formats ANSI output with glyph
- [x] 3.2 Add staleness detection (if `ts` > 120s old, append `?`)
- [x] 3.3 Add missing-file handling (output nothing, exit 0)
- [x] 3.4 Verify script works on both bash (macOS) and bash (Linux) with no GNU-isms

## 4. Update installer for cross-platform support

- [x] 4.1 Detect platform in `install.sh` (Darwin vs Linux)
- [x] 4.2 Install base deps only on Linux, full deps on macOS
- [x] 4.3 Register `statusLine` in `~/.claude/settings.json` (idempotent, both platforms)
- [x] 4.4 Update `hooks/start.sh` to launch `--headless` on Linux, full app on macOS

## 5. Testing

- [x] 5.1 Test headless mode starts and writes cache file (Linux)
- [x] 5.2 Test statusline script reads cache and outputs correct format
- [x] 5.3 Test staleness indicator appears when cache is old
- [x] 5.4 Test menu bar mode still works on macOS and also writes cache
- [x] 5.5 Test installer registers statusLine correctly on both platforms

## 6. Documentation

- [x] 6.1 Update README to reflect cross-platform support and statusline feature
- [x] 6.2 Document `--headless` flag and cache file location
