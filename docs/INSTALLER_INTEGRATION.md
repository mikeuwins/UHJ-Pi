# Installer Integration Guide

This guide shows how to integrate the ATK patch application into your installer scripts.

## Overview

The ATK patches must be applied **after** ATK is installed but **before** custom extensions are installed. This ensures the core ATK classes are properly modified before any code tries to use them.

## Integration Point

Add the patch application **after** ATK installation and asset downloads, but **before** custom extensions:

```bash
# After this section:
# - ATK quark installation
# - ATK assets download (kernels, matrices, sounds)
# - AmbiVerbSC installation

# Apply ATK core modifications
echo "Applying ATK core modifications..."
PROJECT_ROOT="/home/$ACTUAL_USER/UHJ-Pi"
if [ -f "$PROJECT_ROOT/scripts/install/apply-atk-patches.sh" ]; then
    bash "$PROJECT_ROOT/scripts/install/apply-atk-patches.sh"
    if [ $? -ne 0 ]; then
        echo "WARNING: ATK patch application failed, but continuing..."
        echo "You may need to apply patches manually later."
    fi
else
    echo "WARNING: ATK patch script not found at: $PROJECT_ROOT/scripts/install/apply-atk-patches.sh"
    echo "Skipping patch application. You may need to apply patches manually."
fi

# Then continue with custom extensions installation
```

## Example: Full Integration in install-esi.sh

```bash
# STEP 10: Install ATK and handle GUI component cleanup
echo "Step 10: Installing ATK and cleaning up GUI components..."
cd /home/$ACTUAL_USER

# Install ATK quark
echo "Installing ATK quark..."
if sudo -u $ACTUAL_USER sclang -e 'Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git")'; then
    echo "ATK quark installation successful"
else
    echo "ERROR: ATK quark installation failed!"
    exit 1
fi

# Remove problematic GUI components
echo "Removing problematic GUI components..."
rm -rf /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Download ATK kernels, matrices, and sounds
echo "Downloading ATK assets..."
echo "Downloading ATK kernels..."
if sudo -u $ACTUAL_USER sclang -e 'Atk.downloadKernels()'; then
    echo "ATK kernels download successful"
else
    echo "ERROR: ATK kernels download failed!"
    exit 1
fi

echo "Downloading ATK matrices..."
if sudo -u $ACTUAL_USER sclang -e 'Atk.downloadMatrices()'; then
    echo "ATK matrices download successful"
else
    echo "ERROR: ATK matrices download failed!"
    exit 1
fi

echo "Downloading ATK sounds..."
if sudo -u $ACTUAL_USER sclang -e 'Atk.downloadSounds()'; then
    echo "ATK sounds download successful"
else
    echo "ERROR: ATK sounds download failed!"
    exit 1
fi

# Install AmbiVerbSC
echo "Installing AmbiVerbSC..."
if sudo -u $ACTUAL_USER sclang -e 'Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC")'; then
    echo "AmbiVerbSC installation successful"
else
    echo "ERROR: AmbiVerbSC installation failed!"
    exit 1
fi

# STEP 10.5: Apply ATK core modifications
echo "Step 10.5: Applying ATK core modifications..."
PROJECT_ROOT="/home/$ACTUAL_USER/UHJ-Pi"
if [ -f "$PROJECT_ROOT/scripts/install/apply-atk-patches.sh" ]; then
    bash "$PROJECT_ROOT/scripts/install/apply-atk-patches.sh"
    if [ $? -ne 0 ]; then
        echo "WARNING: ATK patch application had issues, but continuing..."
        echo "You may need to apply patches manually and recompile SuperCollider class library."
    else
        echo "ATK patches applied successfully!"
        echo "IMPORTANT: User must recompile SuperCollider class library (Ctrl+Shift+P) after installation."
    fi
else
    echo "WARNING: ATK patch script not found at: $PROJECT_ROOT/scripts/install/apply-atk-patches.sh"
    echo "Skipping patch application. Patches must be applied manually."
fi

# STEP 11: Install custom user classes
echo "Step 11: Installing custom user classes..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions

# Ensure SuperCollider Extensions directory exists
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# Copy custom extensions...
```

## Important Notes

### 1. Recompilation Required

**CRITICAL:** After applying patches, users **must** recompile SuperCollider's class library:

- Open SuperCollider IDE
- Press `Ctrl+Shift+P` (Linux/Windows) or `Cmd+Shift+P` (macOS)
- Select "Recompile Class Library"

The installer should warn users about this requirement.

### 2. Patch File Location

The patch script expects patch files at:
- `$PROJECT_ROOT/scripts/patches/atk/ATK.sc.patch` (or `ATK.sc`)
- `$PROJECT_ROOT/scripts/patches/atk/FoaMatrix.sc.patch` (or `FoaMatrix.sc`)

If patch files (`.patch`) are not available, the script will try to use the full modified source files (`.sc`).

### 3. Error Handling

The patch script should not fail the entire installation if patches fail. It should:
- Create backups before patching
- Warn if patches fail
- Continue installation (user can patch manually later)

### 4. Backup Files

Backups are created automatically with timestamps:
- `ATK.sc.backup.YYYYMMDD_HHMMSS`
- `FoaMatrix.sc.backup.YYYYMMDD_HHMMSS`

Users can restore from backups if needed.

## Testing the Integration

After integrating, test the installer:

1. Run the installer on a clean system
2. Verify patches are applied:
   ```bash
   grep -q "PHJ encoder uses 4-lane interleaved" \
     ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc
   ```
3. Verify `new5_2` method exists:
   ```bash
   grep -q "new5_2" \
     ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc
   ```
4. Test in SuperCollider:
   ```supercollider
   FoaDecoderMatrix.new5_2; // Should not error
   ```

## Manual Patch Application

If automatic patching fails, users can apply manually:

```bash
cd ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes
bash ~/UHJ-Pi/scripts/install/apply-atk-patches.sh
```

Then recompile SuperCollider class library.

## Alternative: Direct File Copy

If patch files aren't available, you can copy the modified files directly:

```bash
# Backup originals
cp ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc \
   ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc.backup

cp ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc \
   ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc.backup

# Copy modified versions (if you have them)
cp /path/to/modified/ATK.sc \
   ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc

cp /path/to/modified/FoaMatrix.sc \
   ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc
```

## Checklist

- [ ] ATK quark installed
- [ ] ATK assets downloaded (kernels, matrices, sounds)
- [ ] AmbiVerbSC installed
- [ ] Patch script called
- [ ] Patches applied successfully (or warned if failed)
- [ ] Custom extensions installed
- [ ] User notified about recompilation requirement

## See Also

- `scripts/install/apply-atk-patches.sh` - Patch application script
- `docs/SUPERCOLLIDER_EXTENSIONS.md` - Full documentation
- `docs/DEVELOPER_QUICK_REFERENCE.md` - Developer reference

