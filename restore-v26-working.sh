#!/bin/bash
# Restore v26 to known working state
# This restores both the app and ble-ht.sh to the versions that were working

echo "Restoring v26 to known working state..."
cd "$HOME/UHJ-Pi" || exit 1

# Restore ble-ht.sh from commit 48787bd (known working)
git show 48787bd:ble-ht.sh > ble-ht.sh
chmod +x ble-ht.sh

# Restore v26 app from commit 8aa4850 (known working)
git show 8aa4850:supercollider/app/UHJ_v26_PLAYER_SF.scd > supercollider/app/UHJ_v26_PLAYER_SF.scd

echo "✓ Restored ble-ht.sh from commit 48787bd"
echo "✓ Restored UHJ_v26_PLAYER_SF.scd from commit 8aa4850"
echo ""
echo "To test:"
echo "  cd ~/UHJ-Pi"
echo "  sclang supercollider/app/UHJ_v26_PLAYER_SF.scd"

