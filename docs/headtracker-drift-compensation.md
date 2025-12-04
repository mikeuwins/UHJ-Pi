# Headtracker Drift Compensation

## Overview

The headtracker implementation includes drift compensation and wrap-around protection to prevent unwanted movement and getting stuck at extreme positions.

## Components

### 1. Exponential Smoothing

**Purpose:** Reduces jitter and small fluctuations from the raw headtracker data.

**Formula:**
```
smoothed = (old_smoothed × 0.85) + (new_raw × 0.15)
```

**How it works:**
- The smoothing factor (0.15 = 15%) controls how quickly the smoothed value follows new input
- Lower values = more smoothing (slower response, less jitter)
- Higher values = less smoothing (faster response, more jitter)
- Current setting: 15% (good balance between responsiveness and stability)

**Why it works:**
- Each new reading only influences the smoothed value by 15%
- The remaining 85% comes from previous smoothed values
- This creates a "memory" that dampens sudden changes

### 2. Dead Zone

**Purpose:** Prevents drift when the device should be centered.

**How it works:**
- If the smoothed value is within 2% of center (0.49-0.51), it snaps to exactly 0.5
- This prevents tiny movements from accumulating into noticeable drift
- Only applies when moving from outside the dead zone into it

**Current setting:** 2% dead zone around center

**Why it works:**
- Small sensor noise near center gets filtered out
- User doesn't notice the snap because they're already near center
- Prevents gradual drift accumulation over time

### 3. Change Threshold

**Purpose:** Only updates the knob when movement is significant.

**How it works:**
- Calculates the absolute change from the last value
- Only updates if change > 0.5% (0.005)
- Filters out micro-movements that would cause visible drift

**Current setting:** 0.5% minimum change threshold

**Why it works:**
- Prevents every tiny sensor fluctuation from updating the display
- Reduces unnecessary processing
- Makes the control feel more stable

### 4. Wrap-Around Detection (Tumble Axis)

**Purpose:** Prevents getting stuck at 180° when rotating all the way around.

**How it works:**
- Detects when change > 0.5 (e.g., 0.9 → 0.1) - indicates wrap-around past 180°
- On wrap-around, updates directly without smoothing to avoid getting stuck
- For distance calculations, uses shorter path around circle (if change > 0.5, use `1.0 - change`)

**Why it's needed:**
- When rotating past 180°, the value jumps from near 1.0 to near 0.0 (or vice versa)
- Without detection, smoothing would try to interpolate through the jump
- This causes the value to get stuck at the wrap point
- Direct update on wrap-around prevents this

**Current setting:** 0.5 threshold for wrap detection

## Implementation Details

### Variables

```supercollider
~htRotateSmoothed = 0.5;  // Smoothed rotation value (0-1, center = 0.5)
~htRotateLast = 0.5;      // Last rotation value for change detection
~htTumbleSmoothed = 0.5;  // Smoothed tumble value (0-1, center = 0.5)
~htTumbleLast = 0.5;      // Last tumble value for change detection
~htSmoothFactor = 0.15;   // Smoothing factor (0-1, lower = more smoothing)
~htDeadZone = 0.02;       // Dead zone around center (ignore changes smaller than this)
~htChangeThreshold = 0.005; // Minimum change threshold to update
~htWrapThreshold = 0.5;   // Threshold to detect wrap-around (if change > this, it's a wrap)
```

### Processing Flow

1. **Map raw HID value** to 0-1 range
2. **Check for wrap-around** (tumble only): if change > 0.5, update directly
3. **Apply exponential smoothing** (if not wrap-around)
4. **Calculate change** from last value (use shorter path if wrap-around)
5. **Check threshold**: only proceed if change > 0.5%
6. **Check dead zone**: if near center, snap to 0.5
7. **Update knob** if outside dead zone

## Tuning Parameters

### Smoothing Factor (`~htSmoothFactor`)
- **Lower (0.05-0.10)**: More smoothing, less jitter, slower response
- **Higher (0.20-0.30)**: Less smoothing, more jitter, faster response
- **Current (0.15)**: Good balance for most use cases

### Dead Zone (`~htDeadZone`)
- **Smaller (0.01)**: More sensitive, may drift slightly
- **Larger (0.05)**: Less sensitive, more stable but larger "dead" area
- **Current (0.02)**: Good balance - 2% of range

### Change Threshold (`~htChangeThreshold`)
- **Smaller (0.001)**: More sensitive, may show micro-movements
- **Larger (0.01)**: Less sensitive, more stable but may feel sluggish
- **Current (0.005)**: Good balance - 0.5% of range

## Applied Axes

- **Rotation (Z-axis)**: Drift compensation (smoothing, dead zone, threshold)
- **Tilt (Y-axis)**: Basic mapping (no drift compensation yet)
- **Tumble (X-axis)**: Full protection (smoothing, dead zone, threshold, wrap-around detection)

## Notes

- Wrap-around detection is most important for tumble (roll) axis, which is most likely to wrap when device is rotated
- Rotation and tilt can also benefit from wrap-around protection in edge cases (e.g., removing headphones)
- The dead zone only activates when moving from outside to inside - it doesn't prevent movement when already outside

