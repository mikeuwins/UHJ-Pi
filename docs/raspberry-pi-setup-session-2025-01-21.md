# Raspberry Pi Setup Session - January 21, 2025

## Overview
This session covered the transition from development to Raspberry Pi 5 deployment, including minimal OS setup, auto-boot configuration, and complex multi-device audio routing for both ESI and Behringer audio interfaces.

## Key Topics Covered

### 1. Minimal Raspberry Pi OS Setup
- **Question**: Will SuperCollider GUI work on minimal (non-desktop) Raspberry Pi OS?
- **Answer**: Yes, with X11 packages installed
- **Required packages**: x11-common, x11-utils, xorg, openbox, xinit, etc.
- **Font support**: LCD fonts need system-wide installation
- **Audio**: JACK, ALSA, and real-time kernel support

### 2. Auto-boot Configuration
- **Goal**: Boot directly to SuperCollider with full-screen GUI
- **7-inch LCD**: Perfect dimensions for existing GUI
- **No menu bar**: Clean, dedicated interface
- **Real-time optimization**: Performance governor, audio priorities

### 3. Multi-Device Audio Routing

#### ESI Setup
- **Input**: Phonorama (2 channels) - controlled via phono-control CLI
- **Output**: Gigaport HD+ (8 channels) - JACK audio server
- **Configuration**: Automatic detection and setup

#### Behringer Setup
- **Input**: UFO202 (2 channels)
- **Output**: UFO202 + UCA202 combined (4 channels total)
- **Challenge**: Both devices appear as identical "USB Codec" devices

### 4. Behringer Device Identification Problem

#### The Problem
- Both UFO202 and UCA202 appear as "USB Codec" with identical descriptors
- Linux cannot distinguish between them by device name alone
- Card numbers can change between boots

#### Solutions Developed

##### 1. USB Port-Based Identification
- Use physical USB port information to distinguish devices
- Create persistent udev rules based on port location
- Label devices physically and use consistent ports

##### 2. Device Identification Script
- `scripts/install/identify-behringer-devices.sh`
- Shows detailed USB information, port mapping, and ALSA card details
- Helps identify which device is on which port

##### 3. Persistent Udev Rules
- `scripts/install/create-behringer-udev-rules.sh`
- Creates udev rules for persistent device naming
- Uses USB port information to create symlinks (ufo202, uca202)

##### 4. Updated Auto-boot Script
- `scripts/install/setup-autoboot.sh`
- Smart device detection with fallback methods
- Handles both ESI and Behringer setups automatically

## Scripts Created

### 1. `setup-autoboot.sh`
**Purpose**: Complete auto-boot setup for Raspberry Pi
**Features**:
- Minimal X11 installation (no desktop environment)
- 7-inch LCD configuration (800x480)
- Real-time audio optimization
- Multi-device audio detection
- Full-screen SuperCollider launch
- Disabled onboard/HDMI audio

### 2. `setup-udev-rules.sh`
**Purpose**: Audio interface-specific udev rules
**Features**:
- ESI Phonorama HID access
- Generic SuperCollider HID access
- User choice for different audio interfaces

### 3. `setup-behringer-routing.sh`
**Purpose**: Complex routing for UFO202 + UCA202
**Features**:
- JACK connection setup
- Multi-device output configuration
- Automatic device detection

### 4. `identify-behringer-devices.sh`
**Purpose**: Identify and distinguish Behringer devices
**Features**:
- USB port mapping
- ALSA card details
- Device identification recommendations

### 5. `create-behringer-udev-rules.sh`
**Purpose**: Create persistent device naming
**Features**:
- USB port-based udev rules
- Persistent symlinks (ufo202, uca202)
- Interactive port number input

## Installation Workflow

### For ESI Setup
1. Install Raspberry Pi OS Lite
2. Clone UHJ-Pi repository
3. Run `sudo ./scripts/install/setup-autoboot.sh`
4. Build and install phono-control
5. Reboot

### For Behringer Setup
1. Install Raspberry Pi OS Lite
2. Clone UHJ-Pi repository
3. Run `sudo ./scripts/install/setup-autoboot.sh`
4. Run `./scripts/install/identify-behringer-devices.sh`
5. Run `sudo ./scripts/install/create-behringer-udev-rules.sh`
6. Unplug/replug devices
7. Test device naming
8. Reboot

## Technical Details

### Audio Configuration
- **Onboard audio**: Disabled via `/boot/config.txt`
- **ALSA configuration**: Multi-device support in `/etc/asound.conf`
- **JACK audio**: Real-time priority, optimized buffer settings
- **Device detection**: Smart fallback methods

### Performance Optimizations
- **CPU governor**: Performance mode
- **Real-time priorities**: Audio group with 95 priority
- **Memory management**: Optimized swappiness and caching
- **Unnecessary services**: Disabled (WiFi, Bluetooth, etc.)

### Display Configuration
- **Resolution**: 800x480 (7-inch LCD)
- **Window manager**: Openbox (minimal)
- **Full-screen**: No decorations, auto-maximize
- **Screen saver**: Disabled

## Next Steps

1. **Test on actual Raspberry Pi 5**
2. **Verify device identification works**
3. **Test audio routing for both setups**
4. **Optimize performance if needed**
5. **Create user documentation**

## Files Modified/Created

### New Scripts
- `scripts/install/setup-autoboot.sh`
- `scripts/install/setup-udev-rules.sh`
- `scripts/install/setup-behringer-routing.sh`
- `scripts/install/identify-behringer-devices.sh`
- `scripts/install/create-behringer-udev-rules.sh`

### Updated Files
- `supercollider/app/UHJ_Ambisonic_System_v17_lcd_fonts.scd` (committed with LCD fonts)

## Notes for Tomorrow

- Review the Behringer device identification approach
- Consider if the routing complexity is manageable
- Test the auto-boot script on actual hardware
- Verify that the 7-inch LCD works as expected
- Consider adding a way to exit full-screen mode for maintenance

## Resources

- **Raspberry Pi OS**: Minimal installation with X11
- **Real-time kernel**: Available via `linux-image-rt-arm64`
- **JACK audio**: Real-time audio server with low latency
- **ALSA**: Advanced Linux Sound Architecture
- **udev**: Device management and persistent naming 