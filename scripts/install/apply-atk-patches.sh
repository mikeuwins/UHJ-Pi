#!/bin/bash
# apply-atk-patches.sh
# Applies ATK core modifications for PHJ encoder and 5.1.2 decoder support
# This script should be run after ATK quark installation

set -e  # Exit on error

ACTUAL_USER="${SUDO_USER:-$USER}"
ATK_CLASSES_DIR="/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Applying ATK core modifications..."

# Check if ATK is installed
if [ ! -d "$ATK_CLASSES_DIR" ]; then
    echo "ERROR: ATK classes directory not found: $ATK_CLASSES_DIR"
    echo "Please install ATK quark first:"
    echo "  Quarks.install(\"https://github.com/ambisonictoolkit/atk-sc3.git\");"
    exit 1
fi

# Backup original files
echo "Creating backups..."
sudo -u "$ACTUAL_USER" cp "$ATK_CLASSES_DIR/ATK.sc" "$ATK_CLASSES_DIR/ATK.sc.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
sudo -u "$ACTUAL_USER" cp "$ATK_CLASSES_DIR/FoaMatrix.sc" "$ATK_CLASSES_DIR/FoaMatrix.sc.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Check if patch files exist in project
PATCH_DIR="$PROJECT_ROOT/scripts/patches/atk"
if [ ! -d "$PATCH_DIR" ]; then
    echo "ERROR: Patch directory not found: $PATCH_DIR"
    echo "Creating patch files from modified versions..."
    exit 1
fi

# Apply patches
echo "Applying ATK.sc patch (PHJ encoder support)..."
if [ -f "$PATCH_DIR/ATK.sc.patch" ]; then
    cd "$ATK_CLASSES_DIR"
    sudo -u "$ACTUAL_USER" patch -p1 -b < "$PATCH_DIR/ATK.sc.patch" || {
        echo "WARNING: Patch application may have failed. Check for .rej files."
    }
elif [ -f "$PATCH_DIR/ATK.sc" ]; then
    # Direct file replacement (if patch file not available)
    echo "Copying modified ATK.sc..."
    sudo -u "$ACTUAL_USER" cp "$PATCH_DIR/ATK.sc" "$ATK_CLASSES_DIR/ATK.sc"
else
    echo "ERROR: No patch file found for ATK.sc"
    exit 1
fi

echo "Applying FoaMatrix.sc patch (5.1.2 decoder support)..."
if [ -f "$PATCH_DIR/FoaMatrix.sc.patch" ]; then
    cd "$ATK_CLASSES_DIR"
    sudo -u "$ACTUAL_USER" patch -p1 -b < "$PATCH_DIR/FoaMatrix.sc.patch" || {
        echo "WARNING: Patch application may have failed. Check for .rej files."
    }
elif [ -f "$PATCH_DIR/FoaMatrix.sc" ]; then
    # Direct file replacement (if patch file not available)
    echo "Copying modified FoaMatrix.sc..."
    sudo -u "$ACTUAL_USER" cp "$PATCH_DIR/FoaMatrix.sc" "$ATK_CLASSES_DIR/FoaMatrix.sc"
else
    echo "ERROR: No patch file found for FoaMatrix.sc"
    exit 1
fi

echo "ATK patches applied successfully!"
echo ""
echo "Next steps:"
echo "1. Open SuperCollider IDE"
echo "2. Recompile class library (Ctrl+Shift+P or Cmd+Shift+P)"
echo "3. Test with: FoaDecoderMatrix.new5_2;"
echo ""

