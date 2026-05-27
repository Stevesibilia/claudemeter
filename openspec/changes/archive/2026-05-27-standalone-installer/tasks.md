## 1. Version tracking

- [x] 1.1 Add `.version` file to repo root containing current version tag
- [x] 1.2 Add `.version` to release process (update before tagging)

## 2. Refactor existing scripts for relocatability

- [x] 2.1 Modify `run.sh` to resolve install dir dynamically (not assume repo root)
- [x] 2.2 Modify `hooks/start.sh` and `hooks/stop.sh` to derive paths from their own location
- [x] 2.3 Modify `hooks/install.sh` to accept `INSTALL_DIR` env var for hook path registration

## 3. Create install.sh

- [x] 3.1 Implement argument parsing (`--uninstall`, env vars `CLAUDEMETER_VERSION`, `INSTALL_DIR`)
- [x] 3.2 Implement version resolution (default to latest GitHub release tag via API)
- [x] 3.3 Implement download + extract (curl tarball, strip-components into install dir)
- [x] 3.4 Implement version skip check (compare `.version` file vs desired)
- [x] 3.5 Implement venv creation with deps-hash tracking (sha256 of requirements.txt)
- [x] 3.6 Implement hook registration (call `hooks/install.sh` if hooks not already present)
- [x] 3.7 Implement idempotency output protocol (`CHANGED:` / `OK:` lines, exit codes)
- [x] 3.8 Implement `--uninstall` path (remove dir, deregister hooks, kill process)

## 4. Testing

- [x] 4.1 Test fresh install on clean system (no prior claudemeter)
- [x] 4.2 Test idempotent re-run (second run prints `OK: already up to date`)
- [x] 4.3 Test version upgrade (change CLAUDEMETER_VERSION, verify CHANGED output)
- [x] 4.4 Test uninstall (verify dir removed, hooks gone, process killed)
- [x] 4.5 Test with custom INSTALL_DIR

## 5. Documentation

- [x] 5.1 Update README install section with curl-pipe-bash one-liner
- [x] 5.2 Add Ansible usage example to README
- [x] 5.3 Document env vars and flags in install.sh header comment
- [ ] 5.4 Create first GitHub release tag
