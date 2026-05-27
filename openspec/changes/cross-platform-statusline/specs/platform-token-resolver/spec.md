## ADDED Requirements

### Requirement: Token resolution uses Keychain on macOS, file on Linux
The token resolver SHALL attempt macOS Keychain first (if `security` binary exists), then fall back to `~/.claude/.credentials.json`.

#### Scenario: macOS with valid Keychain entry
- **WHEN** running on macOS and the Keychain contains the Claude Code credential
- **THEN** the token is read from the Keychain

#### Scenario: Linux (no Keychain)
- **WHEN** running on Linux (no `security` binary)
- **THEN** the token is read from `~/.claude/.credentials.json`

#### Scenario: macOS with empty Keychain but valid credentials file
- **WHEN** running on macOS and Keychain lookup fails but credentials file exists
- **THEN** the token is read from the credentials file

### Requirement: Token re-read on authentication failure
The resolver SHALL re-read the token from its source when the API returns HTTP 401.

#### Scenario: Token expired and refreshed
- **WHEN** the API returns 401
- **THEN** the poller re-reads the token from the appropriate source
- **THEN** the next poll uses the new token
