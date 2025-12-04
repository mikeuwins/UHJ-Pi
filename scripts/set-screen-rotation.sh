#!/bin/bash

# Simple helper to set Qt EGLFS screen rotation for the current user.
# Usage:
#   set-screen-rotation.sh        # defaults to 180
#   set-screen-rotation.sh 0      # force 0 degrees
#   set-screen-rotation.sh 180    # force 180 degrees
#
# This only changes the Qt EGLFS rotation (QT_QPA_EGLFS_ROTATION) in
# ~/.bashrc and ~/.profile. It does not touch any global udev/libinput
# touch settings.

set -e

ROTATION="${1:-180}"

if [ "$ROTATION" != "0" ] && [ "$ROTATION" != "180" ]; then
  echo "Usage: $0 [0|180]"
  echo "  0   normal orientation"
  echo "  180 flipped upside-down"
  exit 1
fi

echo "Setting QT_QPA_EGLFS_ROTATION to $ROTATION for user $USER"

update_file() {
  local file="$1"
  if [ -f "$file" ]; then
    # Remove any existing QT_QPA_EGLFS_ROTATION lines
    sed -i.bak '/QT_QPA_EGLFS_ROTATION/d' "$file"
  fi
  echo "export QT_QPA_EGLFS_ROTATION=$ROTATION" >> "$file"
}

update_file "$HOME/.bashrc"
update_file "$HOME/.profile"

echo "Done. Reboot or log out/in for changes to take effect."


