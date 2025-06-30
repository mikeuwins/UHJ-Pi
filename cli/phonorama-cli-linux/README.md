# ESI Phonorama Control

This is a Linux command-line application to control the [ESI Phonorama](https://www.esi-audio.com/products/phonorama/) USB audio device.

While Linux provides basic audio driver support for the Phonorama, the official control panel software is only available for Windows and macOS. This program is based upon the excellent [ESI Maya22 Linux Control](https://github.com/rabits/esi-maya22-linux) by rabits, incorporating additional GPIO commands necessary to switch the phono pre-amp stage between line, moving coil (MC) and moving magnet (MM) inputs.  Input and output levels, headphone, and monitoring options can also be controlled directly from Linux. 

## Features

- Switch input channel between Line, Moving Coil (MC), Moving Magnet (MM), or Mute  
- Adjust input volume for left and right channels  
- Adjust output volume for left and right channels  
- Enable or disable headphone output  
- Enable or disable input monitoring  
- Saves settings to a JSON config file for persistence  

## Build

* Install build requirements:  
  ```bash
  sudo apt-get install build-essential libhidapi-dev
  ```
  
* Ensure the build script is executable:
  ```bash
   chmod +x build.sh
  ```
  
* Build application:  
  ```bash
  ./build.sh
  ```
  
* Copy app to local bin:  
  ```bash
  sudo cp phono-control /usr/local/bin
  ```

## Configuration 
User settings are stored in `~/.config/phonorama/phonorama_config.json` (created automatically).

## Usage

```bash
phono-control -h
Usage: phono-control [options]

  -c <line|MC|MM|mute>   - Set input channel (line, MC, MM, mute)
  -h                      - Show this help message
  -i                      - Enable headphone
  -I                      - Disable headphone
  -d                      - Set default values for input/output channels
  -l <0-127>              - Set input left volume
  -r <0-127>              - Set input right volume
  -L <0-145>              - Set output left volume
  -R <0-145>              - Set output right volume
  -M                      - Enable input monitoring
  -m                      - Disable input monitoring
```

## Udev Rules

To allow running the application without root permissions, create the following udev rules:

1. To set permissions for the device (add to `/etc/udev/rules.d/50-esi-phonorama.rules`):

   ```
   KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
   ```

2. Optional: To auto-run the application with default settings when the device is connected (add to `/etc/udev/rules.d/51-esi-phonorama-autostart.rules`):

   ```
   ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2573", ATTR{idProduct}=="0001", RUN+="/usr/local/bin/phono-control -d"
   ```

_Note: Having separate rules keeps auto-start optional and permissions management clear._

## Credits

This project is based on the [ESI Maya22 Linux Control project by rabits](https://github.com/rabits/esi-maya22-linux), which provides control functionality for the ESI Maya22 USB audio device.

