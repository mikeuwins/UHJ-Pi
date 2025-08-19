#!/bin/bash
# Fix ATK visibility and download assets (kernels/matrices/sounds)
# Usage on the Pi (as your normal user):
#   curl -s https://raw.githubusercontent.com/mikeuwins/UHJ-Pi/main/scripts/install/fix-atk-assets.sh | bash

set -euo pipefail

export QT_QPA_PLATFORM=offscreen
USER_HOME="$HOME"
BASE="$USER_HOME/.local/share/SuperCollider"
DQ="$BASE/downloaded-quarks"
EXT="$BASE/Extensions"
LOG="$USER_HOME/atk_fix_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$EXT"
# Best effort ownership fix (ignore errors if sudo not available)
if command -v sudo >/dev/null 2>&1; then
	sudo chown -R "$USER":"$USER" "$BASE" 2>/dev/null || true
fi

# Install ATK quark if missing
if [ ! -d "$DQ/atk-sc3" ]; then
	echo "Installing ATK quark..." | tee -a "$LOG"
	sclang -l /dev/null <<'SC' | tee -a "$LOG"
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
SC
fi

# Ensure ATK is on the class path via Extensions symlink
ln -sfn "$DQ/atk-sc3" "$EXT/atk-sc3"

echo "Recompiling class library..." | tee -a "$LOG"
sclang -l /dev/null <<'SC' | tee -a "$LOG"
0.exit;
SC

echo "Downloading ATK kernels, matrices, and sounds..." | tee -a "$LOG"
sclang -l /dev/null <<'SC' | tee -a "$LOG"
Atk.downloadKernels();
Atk.downloadMatrices();
Atk.downloadSounds();
0.exit;
SC

echo
echo "ATK asset setup complete. Log saved to: $LOG"