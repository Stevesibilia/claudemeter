## Why

Claudemeter currently requires cloning the git repo to install. This creates friction for individual developers (extra step, repo cluttering their filesystem) and makes automated provisioning via Ansible awkward since there's no idempotent install/update mechanism. We need a single `install.sh` that works both as a curl-pipe-bash one-liner and as an Ansible-triggered script with proper idempotency signals.

## What Changes

- Add a self-contained `install.sh` at repo root that downloads a release tarball, sets up venv, and registers hooks — no git clone needed
- The installer is idempotent: prints `CHANGED: <reason>` when it mutates state, `OK: already up to date` when not, enabling Ansible `changed_when` detection
- Accepts `CLAUDEMETER_VERSION` and `INSTALL_DIR` env vars for pinning and path control
- Adds a `.version` file to track installed version
- Adds deps-hash checking to skip venv rebuilds when requirements unchanged
- Refactors `run.sh` and `hooks/install.sh` to work from any `INSTALL_DIR`, not just the repo checkout

## Capabilities

### New Capabilities
- `standalone-installer`: Idempotent install/update script that works standalone (curl-pipe-bash) and under Ansible automation. Handles download, venv setup, hook registration, version tracking, and uninstall.

### Modified Capabilities

## Impact

- `install.sh` (new) — main entry point
- `run.sh` — must support running from installed location, not just repo root
- `hooks/install.sh`, `hooks/start.sh`, `hooks/stop.sh` — paths must be relative to install dir
- `.version` file added to repo (tracks release version)
- GitHub releases become the distribution mechanism (tagged tarballs)
- README install instructions change
