
# Phono Control GUI

This is the graphical user interface (GUI) for the Phono Control system, built using Python and Tkinter.

## Overview

The GUI provides a user-friendly interface to control input sources, volume levels, monitoring, and headphone settings for your phono preamp system. It complements the command-line interface (CLI) for easier interaction.

## Features

- Buttons for selecting input sources: Line, MC (Moving Coil), and MM (Moving Magnet).
- Mute toggle button.
- Two sets of faders for Input and Output levels (Left and Right channels).
- Monitor On/Off toggle button.
- Headphones On/Off toggle button.
- Real-time display of current fader values beneath each fader.
- Layout with controls arranged intuitively for quick access.

## Requirements

- Python 3.x
- Tkinter
- The `phono-control` CLI tool installed and accessible on the system path.

### Installing Tkinter

On most Linux distributions, Tkinter is not installed by default.  
Install it using your package manager:

**Ubuntu/Debian:**
```sh
sudo apt install python3-tk
**Fedora**
sudo dnf install python3-tkinter
**Arch**
sudo pacman -S tk

## Running the GUI

```bash
python3 phono-gui.py
```

Ensure the CLI tool `phono-control` is installed (typically in `/usr/local/bin`) as the GUI interacts with it.

## Notes

- The window title is "Phono Control".
- The GUI script and the CLI tool should be in sync regarding available features.
- For detailed CLI usage, refer to the main README.

## License

The GUI is covered under the GNU General Public License version 3. See the `LICENSE` file for details.
