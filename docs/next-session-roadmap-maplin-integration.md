# Next Session Roadmap: Maplin SM-333 Integration
*Planned for next development session*

## 🎯 Session Goal
Integrate the Maplin SM-333 circuit emulation as the third encoding option in the main UHJ-Pi application, creating a pseudo-quad surround system that can be encoded to B-format and processed like existing options (UHJ, Superstereo).

## 🔄 Integration Strategy

### **Processing Pipeline**
```
Input: Stereo → Maplin SM-333 → Pseudo-Quad → B-Format → Standard Processing
```

### **User Experience Flow**
1. **Select Maplin** from decoder options (alongside UHJ, Superstereo)
2. **Open Maplin Overlay** for control adjustments
3. **Adjust three rotary controls** for surround processing
4. **Apply presets** for quick setup
5. **Process through standard B-format pipeline** for consistency

## 📋 Development Phases

### **Phase 1: Core Integration**

#### **Main App Integration**
- [ ] Add "Maplin SM-333" option to decoder selection buttons
- [ ] Integrate SM-333 SynthDef into existing audio engine
- [ ] Implement quad-to-B-format conversion function
- [ ] Test full processing pipeline end-to-end

#### **Audio Engine Modifications**
```supercollider
// Add to main audio engine
case \maplin, {
    // Create Maplin SM-333 synth
    ~maplinSynth = Synth(\maplinSM333Enhanced);
    
    // Convert quad output to B-format
    ~quadToBFormat = Synth(\quadToBFormat);
    
    // Continue with standard B-format processing
    ~bFormatSynth = Synth(\bFormatProcessor);
};
```

#### **B-Format Conversion**
```supercollider
// Quad to B-Format conversion SynthDef
SynthDef(\quadToBFormat, {
    var frontLeft, frontRight, rearLeft, rearRight;
    var w, x, y, z;
    
    // Input from Maplin quad output
    frontLeft = In.ar(0);
    frontRight = In.ar(1);
    rearLeft = In.ar(2);
    rearRight = In.ar(3);
    
    // B-format encoding
    w = (frontLeft + frontRight + rearLeft + rearRight) * 0.5;
    x = (frontLeft - frontRight) * 0.707;
    y = (frontLeft + frontRight - rearLeft - rearRight) * 0.5;
    z = (rearLeft - rearRight) * 0.707;
    
    // Output B-format
    Out.ar(0, [w, x, y, z]);
}).add;
```

### **Phase 2: User Interface Development**

#### **Maplin Overlay Design**
- **Layout**: Match existing EQ and Ambience overlay style
- **Position**: Consistent with other overlays
- **Size**: Appropriate for three rotary controls and preset buttons

#### **Control Implementation**
```supercollider
// Maplin Overlay Controls
~maplinOverlay = {
    // Three rotary controls
    ~surroundLevelKnob = Knob.new()
        .value_(0.7)
        .action_({ |knob| ~setSurroundLevel.(knob.value) });
        
    ~effectLevelKnob = Knob.new()
        .value_(0.7)
        .action_({ |knob| ~setEffectLevel.(knob.value) });
        
    ~delayTimeKnob = Knob.new()
        .value_(0.025)
        .action_({ |knob| ~setDelayTime.(knob.value.linlin(0, 1, 0.005, 0.050)) });
    
    // Preset buttons
    ~presetAuthenticBtn = Button.new()
        .action_({ ~presetAuthentic.() });
        
    ~presetCleanBtn = Button.new()
        .action_({ ~presetClean.() });
        
    ~presetBypassBtn = Button.new()
        .action_({ ~presetBypass.() });
};
```

#### **Control Labels & Values**
- **Surround Level**: "Surround Level" (0.0-1.0)
- **Effect Level**: "Effect Level" (0.0-1.0)
- **Delay Time**: "Delay Time" (5-50ms)
- **Value Displays**: Real-time parameter values

### **Phase 3: State Management**

#### **Maplin State Persistence**
```supercollider
// Maplin state dictionary
~maplinState = Dictionary.newFrom([
    \surroundLevel, 0.7,
    \effectLevel, 0.7,
    \delayTime, 0.025,
    \saturation, 0.2,
    \bandwidth, 0.2,
    \noiseLevel, 0.1
]);

// Save/restore functions
~saveMaplinState = {
    ~maplinState[\surroundLevel] = ~surroundLevelKnob.value;
    ~maplinState[\effectLevel] = ~effectLevelKnob.value;
    ~maplinState[\delayTime] = ~delayTimeKnob.value;
};

~restoreMaplinState = {
    ~surroundLevelKnob.value_(~maplinState[\surroundLevel]);
    ~effectLevelKnob.value_(~maplinState[\effectLevel]);
    ~delayTimeKnob.value_(~maplinState[\delayTime].linlin(0.005, 0.050, 0, 1));
};
```

#### **Overlay State Management**
- **Open/Close**: Handle overlay visibility states
- **Button Selection**: Show Maplin button as selected when active
- **State Persistence**: Save settings when switching decoders

### **Phase 4: Testing & Refinement**

#### **Functionality Testing**
- [ ] Test Maplin selection and activation
- [ ] Verify overlay controls work correctly
- [ ] Test state persistence when switching decoders
- [ ] Verify quad-to-B-format conversion quality
- [ ] Test with various input sources

#### **Performance Optimization**
- [ ] Monitor CPU usage with Maplin processing
- [ ] Optimize for real-time performance
- [ ] Ensure compatibility with existing features
- [ ] Test on target platform (Raspberry Pi)

#### **User Experience Testing**
- [ ] Verify intuitive control layout
- [ ] Test preset functionality
- [ ] Ensure consistent behavior with other decoders
- [ ] Validate B-format output quality

## 🎛️ Expected Control Interface

### **Main Decoder Selection**
```supercollider
// Add to existing decoder buttons
~maplinBtn = Button.new()
    .states_([["Maplin SM-333", Color.black, Color.gray]])
    .action_({ 
        ~currentDecoder = \maplin;
        ~updateDecoderSelection.();
        ~initializeMaplinAudio.();
    });
```

### **Maplin Overlay Layout**
```
┌─────────────────────────┐
│     Maplin SM-333       │
├─────────────────────────┤
│  Surround    Effect     │
│   Level      Level      │
│   [●●●]     [●●●]      │
│    0.7        0.7       │
│                         │
│   Delay Time            │
│   [●●●●●]              │
│    25ms                 │
│                         │
│ [Authentic] [Clean]     │
│ [Bypass]                │
└─────────────────────────┘
```

## 🔧 Technical Implementation Details

### **File Integration**
- **Source**: `supercollider/app/maplin_sm333_enhanced_opamp.scd`
- **Integration**: Extract SynthDef and control functions
- **Modification**: Adapt for main app integration

### **Parameter Mapping**
```supercollider
// Map overlay controls to synth parameters
~setSurroundLevel = { |level| 
    ~maplinSynth.set('surroundLevel', level);
    ~maplinState[\surroundLevel] = level;
};

~setEffectLevel = { |level| 
    ~maplinSynth.set('effectLevel', level);
    ~maplinState[\effectLevel] = level;
};

~setDelayTime = { |time| 
    ~maplinSynth.set('delayTime', time);
    ~maplinState[\delayTime] = time;
};
```

### **Audio Engine Integration**
```supercollider
// Add to main audio engine initialization
~initializeMaplinAudio = {
    ~maplinSynth = Synth(\maplinSM333Enhanced);
    ~quadToBFormat = Synth(\quadToBFormat);
    
    // Restore saved state
    ~restoreMaplinState.();
};
```

## 🎯 Success Criteria

### **Functional Requirements**
- ✅ Maplin appears as third decoder option
- ✅ Overlay opens/closes correctly
- ✅ Three rotary controls work and persist state
- ✅ Preset buttons function properly
- ✅ Quad-to-B-format conversion works
- ✅ Full processing pipeline functional

### **Quality Requirements**
- ✅ Audio quality matches standalone version
- ✅ Performance acceptable for real-time processing
- ✅ UI consistent with existing overlays
- ✅ State persistence works correctly
- ✅ No conflicts with existing features

## 📚 Resources

### **Existing Code**
- `supercollider/app/maplin_sm333_enhanced_opamp.scd` - Working SM-333 emulation
- Main app files for integration reference
- Existing overlay implementations (EQ, Ambience)

### **Documentation**
- `docs/maplin_sm333_emulation_research.md` - Technical details
- `docs/development-session-2024-12-19.md` - Previous session overview

## 🚀 Next Steps After Integration

### **Potential Enhancements**
- **Advanced Maplin Controls**: Additional circuit parameters
- **Custom Presets**: User-saveable Maplin configurations
- **Performance Monitoring**: Real-time CPU usage display
- **A/B Comparison**: Quick switching between decoders

### **Future Development**
- **Additional Circuit Models**: Other vintage surround processors
- **GUI Improvements**: More sophisticated control interfaces
- **Performance Optimization**: Further efficiency improvements

---

*Roadmap created: December 19, 2024*  
*Target: Next development session*  
*Status: Ready for implementation* 