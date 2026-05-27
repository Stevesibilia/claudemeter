## ADDED Requirements

### Requirement: Installer downloads and extracts release tarball
The installer SHALL download the claudemeter release tarball from GitHub for the specified version and extract it to the install directory.

#### Scenario: Fresh install with default version
- **WHEN** `install.sh` is run with no `CLAUDEMETER_VERSION` set
- **THEN** the installer downloads the latest tagged release and extracts to `~/.local/share/claudemeter`

#### Scenario: Fresh install with pinned version
- **WHEN** `install.sh` is run with `CLAUDEMETER_VERSION=v1.0.0`
- **THEN** the installer downloads the `v1.0.0` tarball and extracts to the install directory

#### Scenario: Custom install directory
- **WHEN** `install.sh` is run with `INSTALL_DIR=/opt/claudemeter`
- **THEN** files are extracted to `/opt/claudemeter` instead of the default location

### Requirement: Installer creates and maintains Python venv
The installer SHALL create a Python virtual environment and install dependencies. It SHALL skip reinstallation when requirements have not changed.

#### Scenario: Fresh venv creation
- **WHEN** no `.venv` directory exists in the install dir
- **THEN** the installer creates a venv and runs `pip install -r requirements.txt`
- **THEN** the installer stores a sha256 hash of `requirements.txt` in `.venv/.deps-hash`

#### Scenario: Dependencies unchanged on update
- **WHEN** the installer runs and `.venv/.deps-hash` matches current `requirements.txt` hash
- **THEN** the installer skips pip install

#### Scenario: Dependencies changed on update
- **WHEN** the installer runs and `.venv/.deps-hash` does NOT match current `requirements.txt` hash
- **THEN** the installer runs `pip install -r requirements.txt` and updates `.deps-hash`

### Requirement: Installer registers Claude Code hooks
The installer SHALL register SessionStart and SessionEnd hooks in `~/.claude/settings.json` pointing to the install directory.

#### Scenario: Hooks not yet registered
- **WHEN** `~/.claude/settings.json` does not contain claudemeter hook entries
- **THEN** the installer adds SessionStart and SessionEnd hooks referencing the install dir

#### Scenario: Hooks already registered with correct paths
- **WHEN** hooks already point to the current install directory
- **THEN** the installer makes no changes to settings.json

### Requirement: Installer is idempotent with machine-readable output
The installer SHALL print `CHANGED: <description>` for each mutation and `OK: already up to date` when no changes are needed. Exit code SHALL be 0 on success, 1 on error.

#### Scenario: Nothing to do
- **WHEN** installed version matches desired version, deps hash matches, hooks registered
- **THEN** the installer prints `OK: already up to date` and exits 0

#### Scenario: Version updated
- **WHEN** installed version differs from desired version
- **THEN** the installer prints `CHANGED: updated to <version>` and exits 0

#### Scenario: Multiple changes
- **WHEN** both version and venv need updating
- **THEN** the installer prints one `CHANGED:` line per mutation and exits 0

#### Scenario: Error during install
- **WHEN** download fails or pip install fails
- **THEN** the installer prints an error message to stderr and exits 1

### Requirement: Installer tracks installed version
The installer SHALL write a `.version` file in the install directory containing the installed version string.

#### Scenario: Version file written on install
- **WHEN** installation completes successfully
- **THEN** a `.version` file exists containing the version tag (e.g., `v1.0.0`)

#### Scenario: Version file used for skip check
- **WHEN** `.version` content matches `CLAUDEMETER_VERSION`
- **THEN** the installer skips the download step

### Requirement: Installer supports uninstall
The installer SHALL accept a `--uninstall` flag that removes the installation and deregisters hooks.

#### Scenario: Uninstall removes files and hooks
- **WHEN** `install.sh --uninstall` is run
- **THEN** the install directory is removed
- **THEN** claudemeter hooks are removed from `~/.claude/settings.json`
- **THEN** any running claudemeter process is stopped

### Requirement: Installer requires no git dependency
The installer SHALL work on a system with only curl and Python 3.10+ available. It SHALL NOT require git.

#### Scenario: Install on system without git
- **WHEN** git is not installed but curl and Python 3.10+ are available
- **THEN** installation completes successfully
