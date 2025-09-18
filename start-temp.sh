#!/usr/bin/env bash
set -euo pipefail

# Launch the archived (a2e4f24) v26 app for comparison testing
APP="$HOME/UHJ-Pi/supercollider/app/UHJ_v26_PLAYER_SF_a2e4f24.scd"

if [ ! -f "$APP" ]; then
  echo "App not found: $APP" >&2
  exit 1
fi

# Ensure DISPLAY is set (headless setups may set this in the environment)
export DISPLAY=${DISPLAY:-:0}

exec sclang "$APP"
