## ADDED Requirements

### Requirement: Statusline script reads cache and outputs formatted text
The statusline script SHALL read `~/.claude/.claudemeter-quota` and output ANSI-colored quota text to stdout.

#### Scenario: Normal display
- **WHEN** cache file exists and is fresh (less than 120 seconds old)
- **THEN** output is formatted as `◔ 5h:47% 7d:12%` (with appropriate glyph) in ANSI orange (`\033[38;5;172m`)

#### Scenario: Cache file missing
- **WHEN** `~/.claude/.claudemeter-quota` does not exist
- **THEN** the script outputs nothing and exits 0

#### Scenario: Cache file is stale
- **WHEN** the cache file's `ts` field is more than 120 seconds in the past
- **THEN** the output appends a `?` indicator (e.g., `◔ 5h:47% 7d:12% ?`)

### Requirement: Statusline script executes in under 50ms
The script SHALL not invoke Python, make network calls, or perform any expensive operations. It SHALL only read a file and format output.

#### Scenario: Performance
- **WHEN** Claude Code executes the statusline command
- **THEN** it completes in under 50ms

### Requirement: Glyph reflects 5h utilization level
The statusline SHALL use the same glyph mapping as the menu bar.

#### Scenario: Glyph selection
- **WHEN** 5h utilization is below 50%
- **THEN** glyph is `◔`
- **WHEN** 5h utilization is 50-74%
- **THEN** glyph is `◑`
- **WHEN** 5h utilization is 75-94%
- **THEN** glyph is `◕`
- **WHEN** 5h utilization is 95% or above
- **THEN** glyph is `●`

### Requirement: Statusline script works identically on macOS and Linux
The script SHALL use only POSIX-compatible shell constructs and standard utilities available on both platforms.

#### Scenario: Run on Linux
- **WHEN** the script runs on a Linux system with bash
- **THEN** it produces the same output as on macOS

### Requirement: Installer registers statusLine in settings.json
The installer SHALL add a `statusLine` entry to `~/.claude/settings.json` pointing to the statusline script. It SHALL be idempotent.

#### Scenario: Fresh registration
- **WHEN** `~/.claude/settings.json` has no `statusLine` key
- **THEN** the installer adds `"statusLine": {"type": "command", "command": "bash <install_dir>/claudemeter-statusline.sh"}`

#### Scenario: Already registered
- **WHEN** `statusLine` already points to the claudemeter script
- **THEN** the installer makes no changes
