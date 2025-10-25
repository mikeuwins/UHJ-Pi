# ATK Kernel Files Installation Guide

## Overview
This project uses the Ambisonic Toolkit (ATK) for kernel-based encoding and decoding. Kernel files must be installed in specific locations for both SuperCollider and REAPER to work properly.

## Kernel File Locations

### SuperCollider / ATK Location
**Linux:**
```
~/.local/share/ATK/kernels/
```

**macOS:**
```
~/Library/Application Support/ATK/kernels/
```

**Windows:**
```
%LOCALAPPDATA%\ATK\kernels\
```

### REAPER Location
**All Platforms:**
```
~/.config/REAPER/Data/ATK/kernels/
```

## Required Kernel Files

### Encoders
Copy the following encoder kernel folders to **BOTH** locations above:

- `FOA/encoders/uhj/` - UHJ encoder kernels (2-channel input)
- `FOA/encoders/phj/` - PHJ encoder kernels (4-channel input: L,R,T,Q)
- `FOA/encoders/super/` - Super Stereo encoder kernels
- `FOA/encoders/spread/` - Spread encoder kernels
- `FOA/encoders/diffuse/` - Diffuse encoder kernels

### Decoders
Copy the following decoder kernel folders to **BOTH** locations above:

- `FOA/decoders/uhj/` - UHJ decoder kernels
- `FOA/decoders/phj/` - PHJ decoder kernels
- `FOA/decoders/` - Other decoder kernels as required

## Installation Script

### Linux
```bash
# Copy from SuperCollider/ATK location to REAPER location
cp -r ~/.local/share/ATK/kernels/FOA/encoders/phj ~/.config/REAPER/Data/ATK/kernels/FOA/encoders/
cp -r ~/.local/share/ATK/kernels/FOA/decoders/phj ~/.config/REAPER/Data/ATK/kernels/FOA/decoders/
```

### macOS
```bash
# Copy from SuperCollider/ATK location to REAPER location
cp -r ~/Library/Application\ Support/ATK/kernels/FOA/encoders/phj ~/.config/REAPER/Data/ATK/kernels/FOA/encoders/
cp -r ~/Library/Application\ Support/ATK/kernels/FOA/decoders/phj ~/.config/REAPER/Data/ATK/kernels/FOA/decoders/
```

### Windows (PowerShell)
```powershell
# Copy from SuperCollider/ATK location to REAPER location
Copy-Item -Recurse "$env:LOCALAPPDATA\ATK\kernels\FOA\encoders\phj" "$env:USERPROFILE\.config\REAPER\Data\ATK\kernels\FOA\encoders\"
Copy-Item -Recurse "$env:LOCALAPPDATA\ATK\kernels\FOA\decoders\phj" "$env:USERPROFILE\.config\REAPER\Data\ATK\kernels\FOA\decoders\"
```

## Verification

### Verify SuperCollider/ATK Location
```bash
ls ~/.local/share/ATK/kernels/FOA/encoders/phj/
```

Should show:
```
44100/  48000/  88200/  96000/  176400/  192000/
```

### Verify REAPER Location
```bash
ls ~/.config/REAPER/Data/ATK/kernels/FOA/encoders/phj/
```

Should show the same structure.

## Troubleshooting

### Issue: PHJ encoder is silent in REAPER
**Solution:** Ensure the PHJ kernel files are copied to the REAPER ATK location:
```bash
cp -r ~/.local/share/ATK/kernels/FOA/encoders/phj ~/.config/REAPER/Data/ATK/kernels/FOA/encoders/
```

### Issue: Kernel files not found in SuperCollider
**Solution:** Ensure kernel files are in the SuperCollider/ATK location. You may need to install ATK kernels separately.

### Issue: Mismatch between plugin expectations
**Note:** JSFX plugins in REAPER use relative paths like `ATK/kernels/...` which resolve to `~/.config/REAPER/Data/ATK/kernels/`

## Important Notes

1. **Both locations are required**: Kernel files must exist in both the SuperCollider/ATK location AND the REAPER location for the respective applications to work.

2. **File structure must match**: The folder structure (sample rate directories, kernel size directories, subject directories) must be identical in both locations.

3. **Platform-specific paths**: Use the correct path for your operating system (see locations above).

4. **Synchronization**: When adding new kernel files, remember to copy them to **BOTH** locations.

## References

- ATK Documentation: https://github.com/ambisonictoolkit/atk-kernels
- ATK Kernels Repository: https://github.com/ambisonictoolkit/atk-kernels
- REAPER ATK Integration: See `reaper/jsfx/ATK/` folder
