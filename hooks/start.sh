#!/usr/bin/env bash
# SessionStart hook — launch Claudemeter if not already running
pgrep -qf "python.*claudemeter\.py" || \
  nohup "$(dirname "$0")/../run.sh" >> /tmp/claudemeter.log 2>&1 &
