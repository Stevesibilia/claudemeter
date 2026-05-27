## ADDED Requirements

### Requirement: Poller runs in headless mode without GUI dependencies
The poller SHALL run without importing `rumps` or `pyobjc` when started with `--headless` flag. It SHALL only require `httpx` as an external dependency.

#### Scenario: Start in headless mode on Linux
- **WHEN** `claudemeter.py --headless` is executed on a Linux system without rumps/pyobjc installed
- **THEN** the poller starts successfully and begins polling

#### Scenario: Start in headless mode on macOS
- **WHEN** `claudemeter.py --headless` is executed on macOS
- **THEN** the poller starts without launching a menu bar app

### Requirement: Poller writes quota data to JSON cache file
The poller SHALL write poll results to `~/.claude/.claudemeter-quota` as JSON after every successful API poll. The write SHALL be atomic (write to temp file, then rename).

#### Scenario: Successful poll writes cache
- **WHEN** the poller completes a successful API poll
- **THEN** `~/.claude/.claudemeter-quota` contains JSON with keys `s`, `w`, `sr`, `wr`, `st`, `ts`
- **THEN** `ts` is the unix timestamp of the poll

#### Scenario: Failed poll does not overwrite cache
- **WHEN** the API poll fails (network error, 5xx, etc.)
- **THEN** the existing cache file is NOT overwritten
- **THEN** the previous valid data remains

#### Scenario: Atomic write prevents partial reads
- **WHEN** the poller writes the cache file
- **THEN** it writes to a temporary file first and renames it to the final path

### Requirement: Poller exits cleanly on signals
The poller SHALL handle SIGTERM and SIGINT gracefully, exiting with code 0.

#### Scenario: SIGTERM sent to poller
- **WHEN** SIGTERM is sent to the poller process
- **THEN** the poller exits with code 0 within 1 second

### Requirement: Menu bar mode also writes cache file
When running in menu bar mode (macOS, no `--headless`), the app SHALL also write the cache file after each poll, enabling the statusline to work simultaneously.

#### Scenario: Menu bar app writes cache
- **WHEN** claudemeter runs in menu bar mode and completes a poll
- **THEN** `~/.claude/.claudemeter-quota` is updated with the same data shown in the menu bar
