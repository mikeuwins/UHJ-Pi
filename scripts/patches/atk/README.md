# ATK Core Patches

This directory contains patches for the ATK (Ambisonic Toolkit) core classes.

## Patch Files

### `ATK.sc.patch` or `ATK.sc`
- **Purpose:** Adds PHJ encoder support to `AtkKernelConv`
- **Modifies:** `AtkKernelConv.ar` method
- **What it does:** Detects PHJ encoder kernels (4×4 shape) and handles 4-lane interleaved format

### `FoaMatrix.sc.patch` or `FoaMatrix.sc`
- **Purpose:** Adds `new5_2` method to `FoaDecoderMatrix`
- **Modifies:** `FoaDecoderMatrix` class
- **What it does:** Adds 5.1.2 decoder support with height channel handling

## Usage

The patches are automatically applied by `scripts/install/apply-atk-patches.sh` during installation.

## Manual Application

If you need to apply patches manually:

```bash
cd ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes
patch -p1 < /path/to/UHJ-Pi/scripts/patches/atk/ATK.sc.patch
patch -p1 < /path/to/UHJ-Pi/scripts/patches/atk/FoaMatrix.sc.patch
```

## Backup Files

The patch script creates backups with timestamps:
- `ATK.sc.backup.YYYYMMDD_HHMMSS`
- `FoaMatrix.sc.backup.YYYYMMDD_HHMMSS`

## Reverting Patches

To revert a patch:

```bash
cd ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes
# Find the most recent backup
cp ATK.sc.backup.* ATK.sc
cp FoaMatrix.sc.backup.* FoaMatrix.sc
```

## Note

The patch files (`.patch`) are preferred, but if they're not available, the script will use the full modified source files (`.sc`) instead.

