## Context

Claudemeter is a single-file Python app (~200 LOC) with 3 pip dependencies, launched via `run.sh` and wired into Claude Code via session hooks. Currently requires git clone. Target users are SparkFabrik developers provisioned via Ansible, but the install mechanism must also work standalone via curl-pipe-bash.

## Goals / Non-Goals

**Goals:**
- Single `install.sh` that handles fresh install and updates identically
- Full idempotency with machine-readable output for Ansible integration
- No dependency on git being installed
- Version pinning support for reproducible provisioning
- Clean uninstall path

**Non-Goals:**
- Auto-update (Ansible or user re-runs installer explicitly)
- Supporting non-macOS platforms
- Package manager distribution (brew, pip)
- Rollback to previous version (just pin older version and re-run)

## Decisions

### 1. Single `install.sh` as the universal entry point

Both humans and Ansible use the same script. No separate "ansible role" or "setup.py". The script is fetched from GitHub at the desired version, so it always matches the version being installed.

Alternative considered: separate Ansible role wrapping raw file operations. Rejected because it duplicates logic and drifts from the standalone path.

### 2. GitHub release tarballs as distribution

Use `https://github.com/Stevesibilia/claudemeter/archive/refs/tags/<version>.tar.gz`. Tagged releases are the source of truth. No custom artifact builds needed.

Alternative: GitHub Releases with uploaded assets. Rejected — unnecessary complexity for a small project.

### 3. Install location: `~/.local/share/claudemeter`

XDG-compliant, doesn't pollute home directory, predictable. Overridable via `INSTALL_DIR` env var.

### 4. Idempotency via version file + deps hash

- `.version` file in install dir tracks current installed version
- `.venv/.deps-hash` stores sha256 of `requirements.txt` to skip pip when unchanged
- Hooks checked via grep on `~/.claude/settings.json`

Script compares desired state vs current state at each step, only acts on differences.

### 5. Output protocol for Ansible

- `CHANGED: <description>` printed for each mutation (one per line)
- `OK: already up to date` when nothing changed
- Exit 0 = success, exit 1 = error
- Ansible uses `changed_when: "'CHANGED' in result.stdout"`

### 6. Uninstall via `--uninstall` flag

Same script handles uninstall: `install.sh --uninstall`. Removes install dir, deregisters hooks. Avoids needing a separate uninstall script that might not exist if user deleted the dir.

## Risks / Trade-offs

- [curl-pipe-bash security] → Mitigated by pinning to tagged versions; Ansible fetches specific commit SHA if needed
- [Keychain prompt on first run] → Unavoidable macOS behavior, documented
- [Breaking changes in install.sh itself] → Since script is fetched at target version, old installs use old script. Only matters if someone pins `main`
- [venv corruption] → If venv breaks, user re-runs installer which detects hash mismatch and rebuilds
