# UHJ-Pi Project Assessment Guide

This guide highlights the key components of the UHJ-Pi project for assessment purposes.

## Project Overview

UHJ-Pi is a Raspberry Pi-based Ambisonic UHJ transcoder system that provides real-time encoding/decoding of stereo UHJ signals to various output formats (binaural, quad, 5.1, 5.1.2, octagon, etc.). The system is built on SuperCollider with the Ambisonic Toolkit (ATK).

## Core Application Files

### Main Applications (v28 - Current Version)

**Live Input Applications:**
- `supercollider/app/UHJ_v28_ESI_PAIR.scd` - ESI audio interface version
- `supercollider/app/UHJ_v28_BEH_PAIR.scd` - Behringer audio interface version  
- `supercollider/app/UHJ_v28_VIN_PAIR.scd` - Turntable/vinyl deck version
- `supercollider/app/UHJ_v28_GEN_PAIR.scd` - Generic audio interface version

**Player Application:**
- `supercollider/app/UHJ_v28_PLAYER_SF.scd` - File playback version with FLAC support

### Previous Versions (Development History)

Previous versions are preserved to show development progression:
- `supercollider/app/UHJ_v27_*.scd` - Previous version
- `supercollider/app/UHJ_v26_*.scd` - Earlier version
- Various `*_backup.scd` files show incremental development

## Installation Scripts

### Touchscreen Variants (Primary)
- `install-esi-touch.sh` - ESI touchscreen installation
- `install-beh-touch.sh` - Behringer touchscreen installation
- `install-vin-touch.sh` - Turntable touchscreen installation
- `install-gen-touch.sh` - Generic touchscreen installation
- `install-pla-touch.sh` - Player touchscreen installation

### HDMI Variants
- `install-esi-hdmi.sh` - ESI HDMI installation
- `install-beh-hdmi.sh` - Behringer HDMI installation
- `install-vin-hdmi.sh` - Turntable HDMI installation
- `install-gen-hdmi.sh` - Generic HDMI installation

### 180° Screen Rotation Variants
- `install-*-touch-180.sh` - Touchscreen variants with 180° rotation

## Core Extensions & Modifications

### Modified ATK Classes
- `supercollider/extensions/ATK.sc` - Core ATK modifications for PHJ encoder support
- `supercollider/extensions/FoaMatrix.sc` - Matrix classes with 5.1.2 decoder and PHJ support

### Custom Extensions
- `supercollider/extensions/MaplinMatrix/` - Maplin quad encoder/decoder implementation
- `supercollider/extensions/PHJEncoder/` - PHJ encoder implementation

### Decoder Matrices
- `supercollider/extensions/matrices/FOA/decoders/5_0_2/` - 5.1.2 decoder YAML matrices

## Utilities & Tools

### Audio Control
- `cli/phonorama-cli-linux/` - phono-control CLI tool for turntable control
- `ble-ht.sh` - Bluetooth headtracker pairing utility
- `mount-usb.sh` - USB drive mounting utility

### Python Scripts
- `phython/b-vhap/` - B-VHAP (Vertical Hemispherical Amplitude Panning) implementation
- `phython/phonorama-gui-sclang/` - Phonorama GUI integration scripts

### Launch Scripts
- `start-esi.sh`, `start-beh.sh`, `start-vin.sh`, `start-gen.sh` - Live input launchers
- `start-player.sh` - Player launcher
- `start-beh-mac.sh` - macOS Behringer launcher

## Documentation

### User Guides
- `docs/user-guide/live-input-guide.md` - Live input application user guide
- `docs/user-guide/player-guide.md` - Player application user guide

### Technical Documentation
- `docs/SUPERCOLLIDER_EXTENSIONS.md` - Extension modifications documentation
- `docs/REQUIRED_MODIFICATIONS.md` - Required ATK modifications
- `docs/INSTALLER_INTEGRATION.md` - Installer integration guide
- `docs/DEVELOPER_QUICK_REFERENCE.md` - Developer reference

### Development Notes
- `docs/` - Various development session notes and technical documentation
- `archive/` - Historical development files and prototypes

## Assets

- `assets/audio-samples/` - UHJ test audio files
- `assets/fonts/` - Custom fonts (Arial, Helvetica)
- `assets/impulse-responses/` - IR files for testing
- `assets/artwork*.jpg` - Application artwork

## Key Features

1. **Real-time Encoding/Decoding**: UHJ, SuperStereo, Maplin, and PHJ encoders
2. **Multiple Output Formats**: Stereo, Binaural (IRCAM/CIPIC), Quad (Square/Narrow/Wide), 5.1, 5.1.2, Octagon
3. **Pseudo-spatial Effects**: FoaDimension, FoaZSynthesis, MaplinMatrix
4. **Headtracking Support**: Bluetooth HID headtracker with drift compensation
5. **File Playback**: FLAC support with metadata and artwork extraction
6. **Touchscreen GUI**: Qt-based interface optimised for Raspberry Pi touchscreens

## Repository Structure

- `supercollider/app/` - Main application files
- `supercollider/extensions/` - Custom SuperCollider extensions
- `install-*.sh` - Installation scripts
- `docs/` - Documentation
- `assets/` - Media assets
- `cli/` - Command-line utilities
- `archive/` - Historical development files

## Notes for Assessors

- Previous versions (v21, v22, v27, etc.) are intentionally kept to show development progression
- The `archive/` folder contains historical prototypes and development iterations
- Test scripts and development chat logs are excluded via `.gitignore` to reduce clutter
- All installer scripts reference specific file paths - these must remain unchanged

