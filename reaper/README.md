# Reaper JSFX Plugins for ATK Ambisonic Toolkit

This directory contains Reaper JSFX plugins that extend the ATK (Ambisonic Toolkit) functionality, along with the necessary kernel files and matrices.

## Directory Structure

```
reaper/
├── jsfx/           # Reaper JSFX plugin files (.jsfx)
├── kernels/         # ATK kernel files (cross-platform)
├── matrices/        # ATK matrix files (cross-platform)
├── docs/           # Documentation and examples
└── README.md       # This file
```

## Cross-Platform Compatibility

### Path Detection in JSFX Plugins

JSFX plugins need to detect the correct path to kernel files on different operating systems:

- **macOS**: `/Users/[username]/Library/Application Support/ATK/`
- **Linux**: `~/.local/share/ATK/` or `/home/[username]/.local/share/ATK/`
- **Windows**: `%APPDATA%/ATK/`

### Recommended Approach

1. **Use relative paths** when possible
2. **Implement path detection** in JSFX plugins using platform-specific logic
3. **Provide fallback paths** for different installation scenarios
4. **Use environment variables** where available

## Installation

### For Reaper Users

1. Copy the `.jsfx` files from `jsfx/` to your Reaper Effects folder:
   - **macOS**: `~/Library/Application Support/REAPER/Effects/`
   - **Linux**: `~/.config/REAPER/Effects/`
   - **Windows**: `%APPDATA%/REAPER/Effects/`

2. Ensure kernel files are accessible:
   - Copy `kernels/` and `matrices/` to the appropriate ATK directory
   - Or modify JSFX plugins to point to this project's kernel files

### For Developers

1. Place your JSFX plugins in the `jsfx/` directory
2. Add any custom kernel files to `kernels/`
3. Add any custom matrix files to `matrices/`
4. Update this README with plugin descriptions

## Kernel File Management

The kernel files in this directory are designed to work alongside the main ATK installation. They can be:

1. **Copied to the standard ATK location** (recommended for system-wide use)
2. **Referenced directly** by JSFX plugins using absolute paths
3. **Bundled with plugins** for portable installations

## Testing Cross-Platform Compatibility

To test your plugins on different platforms:

1. **macOS**: Test with standard ATK installation paths
2. **Linux**: Test with both `~/.local/share/ATK/` and project-relative paths
3. **Verify kernel loading** works correctly on both platforms
4. **Check path resolution** in JSFX plugin logs

## Contributing

When adding new JSFX plugins:

1. Follow the naming convention: `ATK_[PluginName].jsfx`
2. Include cross-platform path detection
3. Add documentation in `docs/`
4. Test on both macOS and Linux
