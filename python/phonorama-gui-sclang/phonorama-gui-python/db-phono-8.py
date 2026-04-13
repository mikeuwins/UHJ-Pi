# db-phono-8.py

import tkinter as tk
import subprocess
import json
import os

class PhonoControlGUI:
    def __init__(self):
        # Initialize main window
        self.root = tk.Tk()
        self.root.title("Phono Control")

        # Load configuration if available
        config = {}
        config_file = "phonorama_config.json"
        if os.path.exists(config_file):
            try:
                with open(config_file, "r") as f:
                    config = json.load(f)
            except Exception as e:
                print(f"Warning: Could not load config file: {e}")
                config = {}
        # Default values (phono-control defaults)
        default_cfg = {
            "input_channel": 0x1,  # line
            "input_l": 86,
            "input_r": 86,
            "output_l": 145,
            "output_r": 145,
            "headphone_enabled": 1,
            "monitor_enabled": 1
        }
        # Merge defaults with loaded config
        for key, val in default_cfg.items():
            if key not in config:
                config[key] = val

        # Determine initial input channel and mute state
        chan_code = config.get("input_channel", 0x1)
        if chan_code == 0xC1 or chan_code == 193:  # mute
            initial_channel = ""  # no channel selected
            initial_mute = True
            # If starting in mute, default last_source to line
            self.last_source = "line"
        elif chan_code == 0x1 or chan_code == 1:
            initial_channel = "line"
            initial_mute = False
            self.last_source = "line"
        elif chan_code == 0x8 or chan_code == 8:
            # Phono input (MC or MM), default to MC if unknown
            initial_channel = "MC"
            initial_mute = False
            self.last_source = "MC"
        else:
            # Unexpected code, default to line
            initial_channel = "line"
            initial_mute = False
            self.last_source = "line"

        # Determine initial fader positions in dB (each step = 0.5 dB)
        input_l_raw = config.get("input_l", 86)
        input_r_raw = config.get("input_r", 86)
        output_l_raw = config.get("output_l", 145)
        output_r_raw = config.get("output_r", 145)
        # Convert raw to dB (max value -> 0.0 dB, step of 0.5 dB)
        input_l_db = (input_l_raw - 127) * 0.5
        input_r_db = (input_r_raw - 127) * 0.5
        output_l_db = (output_l_raw - 145) * 0.5
        output_r_db = (output_r_raw - 145) * 0.5

        # Initial toggle states
        headphone_on = bool(config.get("headphone_enabled", 1))
        monitor_on = bool(config.get("monitor_enabled", 1))

        # Top frame for input source selection and mute
        top_frame = tk.Frame(self.root)
        top_frame.pack(side=tk.TOP, fill=tk.X, pady=5)

        # Variables for input source and mute toggle
        self.radio_var = tk.StringVar(value=initial_channel)
        self.mute_var = tk.BooleanVar(value=initial_mute)

        # Callback for input source selection
        def on_source_change():
            chosen = self.radio_var.get()
            if self.mute_var.get():
                # If muted, just store selection (no immediate change)
                self.last_source = chosen
            else:
                # Not muted: apply source change immediately
                self.last_source = chosen
                try:
                    subprocess.run(["phono-control", "-c", chosen], check=False)
                except Exception as e:
                    print(f"Error setting input source: {e}")

        # Create radio buttons for Line, MC, MM (as toggle buttons)
        radio_line = tk.Radiobutton(top_frame, text="Line", variable=self.radio_var,
                                    value="line", indicatoron=0, width=6,
                                    command=on_source_change)
        radio_mc = tk.Radiobutton(top_frame, text="MC", variable=self.radio_var,
                                  value="MC", indicatoron=0, width=6,
                                  command=on_source_change)
        radio_mm = tk.Radiobutton(top_frame, text="MM", variable=self.radio_var,
                                  value="MM", indicatoron=0, width=6,
                                  command=on_source_change)
        radio_line.pack(side=tk.LEFT, padx=2)
        radio_mc.pack(side=tk.LEFT, padx=2)
        radio_mm.pack(side=tk.LEFT, padx=2)

        # Mute toggle button (indicator off for button-style appearance)
        def on_mute_toggle():
            muted = self.mute_var.get()
            try:
                if muted:
                    # Muting on
                    subprocess.run(["phono-control", "-c", "mute"], check=False)
                else:
                    # Muting off: restore last selected source
                    chosen = self.last_source
                    subprocess.run(["phono-control", "-c", chosen], check=False)
                    # If no channel was selected (starting from mute), update radio selection
                    if self.radio_var.get() == "" or self.radio_var.get() not in ["line", "MC", "MM"]:
                        self.radio_var.set(chosen)
            except Exception as e:
                print(f"Error toggling mute: {e}")
        mute_btn = tk.Checkbutton(top_frame, text="Mute", variable=self.mute_var,
                                  indicatoron=0, width=6, command=on_mute_toggle)
        mute_btn.pack(side=tk.LEFT, padx=10)

        # Main frame for volume faders
        main_frame = tk.Frame(self.root)
        main_frame.pack(side=tk.TOP, fill=tk.BOTH, expand=True, padx=10, pady=5)

        # Input and Output frames (with labels)
        input_frame = tk.LabelFrame(main_frame, text="Input Level")
        output_frame = tk.LabelFrame(main_frame, text="Output Level")
        input_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        output_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)

        # Left and right channel labels for input
        inp_left_label = tk.Label(input_frame, text="L")
        inp_right_label = tk.Label(input_frame, text="R")
        inp_left_label.grid(row=0, column=0, pady=(5,0))
        inp_right_label.grid(row=0, column=1, pady=(5,0))
        # Input volume faders (Scale widgets with 0.5 dB resolution)
        self.in_left_scale = tk.Scale(input_frame, from_=-63.5, to=0, orient=tk.VERTICAL,
                                      resolution=0.5, command=lambda val: self._on_input_scale(val, 'L'))
        self.in_right_scale = tk.Scale(input_frame, from_=-63.5, to=0, orient=tk.VERTICAL,
                                       resolution=0.5, command=lambda val: self._on_input_scale(val, 'R'))
        self.in_left_scale.grid(row=1, column=0, padx=10)
        self.in_right_scale.grid(row=1, column=1, padx=10)
        # Labels beneath faders to show current dB value
        self.in_left_val_label = tk.Label(input_frame, text="0.0 dB")
        self.in_right_val_label = tk.Label(input_frame, text="0.0 dB")
        self.in_left_val_label.grid(row=2, column=0, pady=(0,5))
        self.in_right_val_label.grid(row=2, column=1, pady=(0,5))

        # Left and right channel labels for output
        out_left_label = tk.Label(output_frame, text="L")
        out_right_label = tk.Label(output_frame, text="R")
        out_left_label.grid(row=0, column=0, pady=(5,0))
        out_right_label.grid(row=0, column=1, pady=(5,0))
        # Output volume faders (Scale widgets with 0.5 dB resolution)
        self.out_left_scale = tk.Scale(output_frame, from_=-72.5, to=0, orient=tk.VERTICAL,
                                       resolution=0.5, command=lambda val: self._on_output_scale(val, 'L'))
        self.out_right_scale = tk.Scale(output_frame, from_=-72.5, to=0, orient=tk.VERTICAL,
                                        resolution=0.5, command=lambda val: self._on_output_scale(val, 'R'))
        self.out_left_scale.grid(row=1, column=0, padx=10)
        self.out_right_scale.grid(row=1, column=1, padx=10)
        self.out_left_val_label = tk.Label(output_frame, text="0.0 dB")
        self.out_right_val_label = tk.Label(output_frame, text="0.0 dB")
        self.out_left_val_label.grid(row=2, column=0, pady=(0,5))
        self.out_right_val_label.grid(row=2, column=1, pady=(0,5))

        # Bottom frame for monitor and headphone toggles
        bottom_frame = tk.Frame(self.root)
        bottom_frame.pack(side=tk.TOP, pady=5)
        # Headphones toggle
        self.hp_var = tk.BooleanVar(value=headphone_on)
        def on_headphone_toggle():
            hp_on = self.hp_var.get()
            try:
                if hp_on:
                    subprocess.run(["phono-control", "-i"], check=False)
                else:
                    subprocess.run(["phono-control", "-I"], check=False)
            except Exception as e:
                print(f"Error toggling headphone: {e}")
        hp_btn = tk.Checkbutton(bottom_frame, text="Headphones", variable=self.hp_var,
                                indicatoron=0, width=10, command=on_headphone_toggle)
        hp_btn.pack(side=tk.LEFT, padx=5)
        # Monitor toggle
        self.mon_var = tk.BooleanVar(value=monitor_on)
        def on_monitor_toggle():
            mon_on = self.mon_var.get()
            try:
                if mon_on:
                    subprocess.run(["phono-control", "-M"], check=False)
                else:
                    subprocess.run(["phono-control", "-m"], check=False)
            except Exception as e:
                print(f"Error toggling monitor: {e}")
        mon_btn = tk.Checkbutton(bottom_frame, text="Monitor", variable=self.mon_var,
                                 indicatoron=0, width=8, command=on_monitor_toggle)
        mon_btn.pack(side=tk.LEFT, padx=5)

        # Set initial fader positions and labels
        self.in_left_scale.set(input_l_db)
        self.in_right_scale.set(input_r_db)
        self.out_left_scale.set(output_l_db)
        self.out_right_scale.set(output_r_db)
        self._update_val_label(self.in_left_val_label, input_l_db)
        self._update_val_label(self.in_right_val_label, input_r_db)
        self._update_val_label(self.out_left_val_label, output_l_db)
        self._update_val_label(self.out_right_val_label, output_r_db)

        # Apply initial mute/channel and volume settings to hardware
        try:
            if initial_mute:
                subprocess.run(["phono-control", "-c", "mute"], check=False)
            else:
                subprocess.run(["phono-control", "-c", self.last_source], check=False)
            subprocess.run(["phono-control", "-l", str(input_l_raw)], check=False)
            subprocess.run(["phono-control", "-r", str(input_r_raw)], check=False)
            subprocess.run(["phono-control", "-L", str(output_l_raw)], check=False)
            subprocess.run(["phono-control", "-R", str(output_r_raw)], check=False)
            subprocess.run(["phono-control", "-i" if headphone_on else "-I"], check=False)
            subprocess.run(["phono-control", "-M" if monitor_on else "-m"], check=False)
        except Exception as e:
            print(f"Error applying initial settings: {e}")

    def _update_val_label(self, label_widget, value_db):
        """Update the label with the value (in dB) snapped to the nearest 0.5 dB."""
        # Snap to nearest 0.5 dB
        val = round(value_db * 2) / 2.0
        # Avoid displaying negative zero
        if val == 0:
            val = 0.0
        label_widget.config(text=f"{val:.1f} dB")

    def _on_input_scale(self, val, channel):
        """Handle input fader movement for Left ('L') or Right ('R')."""
        try:
            db_val = float(val)
        except Exception:
            return
        if channel == 'L':
            self._update_val_label(self.in_left_val_label, db_val)
            raw = int(round(2 * db_val + 127))
            raw = max(0, min(127, raw))
            try:
                subprocess.run(["phono-control", "-l", str(raw)], check=False)
            except Exception as e:
                print(f"Error setting input L volume: {e}")
        elif channel == 'R':
            self._update_val_label(self.in_right_val_label, db_val)
            raw = int(round(2 * db_val + 127))
            raw = max(0, min(127, raw))
            try:
                subprocess.run(["phono-control", "-r", str(raw)], check=False)
            except Exception as e:
                print(f"Error setting input R volume: {e}")

    def _on_output_scale(self, val, channel):
        """Handle output fader movement for Left ('L') or Right ('R')."""
        try:
            db_val = float(val)
        except Exception:
            return
        if channel == 'L':
            self._update_val_label(self.out_left_val_label, db_val)
            raw = int(round(2 * db_val + 145))
            raw = max(0, min(145, raw))
            try:
                subprocess.run(["phono-control", "-L", str(raw)], check=False)
            except Exception as e:
                print(f"Error setting output L volume: {e}")
        elif channel == 'R':
            self._update_val_label(self.out_right_val_label, db_val)
            raw = int(round(2 * db_val + 145))
            raw = max(0, min(145, raw))
            try:
                subprocess.run(["phono-control", "-R", str(raw)], check=False)
            except Exception as e:
                print(f"Error setting output R volume: {e}")

    def run(self):
        """Start the Tkinter main event loop."""
        self.root.mainloop()

# Run the GUI
if __name__ == "__main__":
    app = PhonoControlGUI()
    app.run()
