# ATK MaplinMatrix (FOA) - User Guide

## What Is MaplinMatrix?

MaplinMatrix is a vintage-style spatial audio effect inspired by the Maplin SM-333 surround sound processor. It creates a width and depth enhancement by:
- Adding subtle chorus-like modulation
- Phase shifting the difference signal
- Applying frequency-dependent delays
- Processing in multiple frequency bands

The effect works on B-format (FOA) audio and creates a surround-like expansion even from stereo sources.

## When To Use

- **Width Enhancement**: Add spaciousness to stereo or B-format content
- **Depth Enhancement**: Create front/back separation
- **Vintage Character**: Add the signature Maplin modulation and coloration
- **B-format Workflows**: Spatial audio production without leaving the FOA domain

## Controls

### Surround Level (0-100%)

Controls the amplitude of the rear/surround channels. Higher values create more pronounced spatial effect.

**Tip**: Start at 80% for typical use. Lower values (40-60%) for subtle enhancement.

### Effect Level (0-100%)

Controls the intensity of the processed difference signal. This is the "Maplin magic" - the phase-shifted and delayed signal that creates the spatial character.

**Tip**: 80% is a good starting point. Higher values create more dramatic effect but may sound artificial if overdone.

### BBD Delay (normalized 0-1: 5-50ms)

Controls the bucket-brigade delay time. BBD delay adds chorus-like modulation. The range is 5ms to 50ms.

**Tip**: 40% (20ms) is the default and works well for most material. Higher values create more pronounced chorusing effect.

### Active (Inactive/Active)

Master bypass switch. When Inactive, the plugin passes through the original signal with minimal processing.

**Tip**: Use the bypass to audition the effect, but note that even bypassed, some level reduction occurs due to the circuit design.

## Typical Settings

### Subtle Enhancement
- Surround: 60%
- Effect: 60%
- BBD Delay: 30% (15ms)
- **Use**: Add slight width without obvious effect

### Classic Maplin
- Surround: 80%
- Effect: 80%
- BBD Delay: 40% (20ms)
- **Use**: Default character, good for most music

### Maximum Effect
- Surround: 100%
- Effect: 100%
- BBD Delay: 100% (50ms)
- **Use**: Strong spatial effect, verging on artificial

### Just Chorus
- Surround: 100%
- Effect: 0%
- BBD Delay: 80% (40ms)
- **Use**: Pure modulation effect without spatial processing

## Signal Flow

```
Input (B-format WXYZ)
  ↓
Decode to L/R
  ↓
Add thermal noise
  ↓
Apply 0.7 gain
  ↓
Sum/Diff matrix
  ↓
Saturation
  ↓
4-stage all-pass
  ↓
Band splitting (LOW/MID/HIGH)
  ↓
Frequency-dependent delays
  ↓
Create front/rear channels
  ↓
BBD delay with modulation
  ↓
Final saturation
  ↓
Encode to B-format WXYZ
  ↓
Output
```

## Important Notes

### Level Reduction

The Maplin circuit includes a 0.7 input gain to prevent distortion. This causes approximately 3dB level reduction even when the effect is bypassed. This is **correct behavior** matching the original hardware.

If you need full level preservation, use REAPER's track gain to compensate.

### Wet/Dry

Unlike typical reverb or delay plugins, MaplinMatrix doesn't have a wet/dry control. The effect is always applied as a mix between original and processed signals following the Maplin circuit design.

### Channel Behavior

- **W Channel**: May reduce slightly due to processing
- **X Channel**: Typically increases (spatial expansion)
- **Y Channel**: May reduce slightly
- **Z Channel**: Passed through unchanged

This energy redistribution is normal and expected.

### CPU Usage

The plugin is moderately CPU-intensive due to:
- Multiple filter stages
- Multiple delay buffers
- Per-sample sine calculations

Typical usage: ~5-10% on modern CPUs per instance.

## Troubleshooting

### Sound is Too Subtle

- Increase Surround Level to 90-100%
- Increase Effect Level to 90-100%
- Verify input levels are adequate

### Sound is Too Extreme

- Reduce Effect Level to 40-60%
- Reduce Surround Level to 40-60%
- Lower BBD Delay to 20-30%

### Static or Distortion

- Check for clipping in the input signal
- Verify plugin isn't oversaturated
- Try reducing input level to the track

### No Effect Heard

- Verify Active is set to 1
- Check B-format is present (W channel non-zero)
- Ensure Surround and Effect levels are above 0%
- Check if signal is too quiet

## Integration with B-format Workflows

### Typical Chain

1. **Encoder**: UHJ → B-format (if starting from stereo)
2. **MaplinMatrix**: Add spatial enhancement
3. **Decoder**: B-format → Binaural (for headphones)
   OR
   **Decoder**: B-format → Speaker layout (for playback)

### Pre/Post Processing

**Before MaplinMatrix**: EQ, compression, shaping  
**After MaplinMatrix**: Binaural decoder, speaker decoder, final EQ

### Side Chain

Use a separate binaural decoder track to monitor while processing in B-format.

## Technical Specifications

- **Format**: B-format (FOA) WXYZ
- **Sample Rate**: 44.1 kHz to 192 kHz
- **Latency**: ~50ms (delay buffers + processing)
- **Status**: Circuit-accurate implementation

## Credits

- **Original Design**: Maplin Electronics SM-333
- **SuperCollider Implementation**: MaplinMatrix class
- **JSFX Port**: Circuit-accurate adaptation for REAPER

## Support

For issues or questions:
- Check this user guide first
- Review the development documentation for technical details
- Verify input format is correct (B-format WXYZ)



