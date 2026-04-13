import tkinter as tk
from tkinter import ttk
import subprocess
import threading
import queue
import json
import os

class PhonoControlGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Phono Control GUI")
        self.configure(padx=8, pady=8)

        self.verbose_window = None

        # Style for highlighting selected input button
        self.style = ttk.Style()
        self.style.configure("TButton", padding=3)
        self.style.map("Selected.TButton", background=[("active", "#80b3ff"), ("!active", "#cce6ff")])

        # Left buttons frame
        button_frame = ttk.Frame(self)
        button_frame.grid(row=0, column=0, sticky="ns")

        self.line_button = ttk.Button(button_frame, text="LINE", width=8, command=lambda: self.select_input('line'))
        self.line_button.grid(row=0, column=0, pady=(0,4), sticky="ew")

        self.mc_button = ttk.Button(button_frame, text="MC", width=8, command=lambda: self.select_input('mc'))
        self.mc_button.grid(row=1, column=0, pady=4, sticky="ew")

        self.mm_button = ttk.Button(button_frame, text="MM", width=8, command=lambda: self.select_input('mm'))
        self.mm_button.grid(row=2, column=0, pady=4, sticky="ew")

        button_frame.rowconfigure(3, weight=1)

        self.mute_button = ttk.Button(button_frame, text="MUTE", width=8, command=lambda: self.select_input('mute'))
        self.mute_button.grid(row=4, column=0, pady=(4,0), sticky="ew")

        # Main frame for faders and right checkbuttons
        main_frame = ttk.Frame(self)
        main_frame.grid(row=0, column=1, sticky="nsew", padx=10)

        # Faders frame
        faders_frame = ttk.Frame(main_frame)
        faders_frame.grid(row=0, column=0, sticky="nw")

        # Input volume box
        input_box = ttk.LabelFrame(faders_frame, text="Input Volume", labelanchor='n')
        input_box.grid(row=0, column=0, padx=(0,20), sticky="n")
        input_box.columnconfigure((0,1), weight=1)

        input_left_frame = ttk.Frame(input_box, width=70)
        input_left_frame.grid(row=0, column=0, padx=8, pady=(12,0))
        input_left_frame.grid_propagate(False)

        self.input_left_fader = ttk.Scale(input_left_frame, from_=127, to=0, orient="vertical", length=180, command=self.update_values)
        self.input_left_fader.pack(expand=True)

        self.input_left_val = ttk.Label(input_box, text="0")
        self.input_left_val.grid(row=1, column=0, pady=(4,10))

        input_right_frame = ttk.Frame(input_box, width=70)
        input_right_frame.grid(row=0, column=1, padx=8, pady=(12,0))
        input_right_frame.grid_propagate(False)

        self.input_right_fader = ttk.Scale(input_right_frame, from_=127, to=0, orient="vertical", length=180, command=self.update_values)
        self.input_right_fader.pack(expand=True)

        self.input_right_val = ttk.Label(input_box, text="0")
        self.input_right_val.grid(row=1, column=1, pady=(4,10))

        # Output volume box
        output_box = ttk.LabelFrame(faders_frame, text="Output Volume", labelanchor='n')
        output_box.grid(row=0, column=1, sticky="n")
        output_box.columnconfigure((0,1), weight=1)

        output_left_frame = ttk.Frame(output_box, width=70)
        output_left_frame.grid(row=0, column=0, padx=8, pady=(12,0))
        output_left_frame.grid_propagate(False)

        self.output_left_fader = ttk.Scale(output_left_frame, from_=145, to=0, orient="vertical", length=180, command=self.update_values)
        self.output_left_fader.pack(expand=True)

        self.output_left_val = ttk.Label(output_box, text="0")
        self.output_left_val.grid(row=1, column=0, pady=(4,10))

        output_right_frame = ttk.Frame(output_box, width=70)
        output_right_frame.grid(row=0, column=1, padx=8, pady=(12,0))
        output_right_frame.grid_propagate(False)

        self.output_right_fader = ttk.Scale(output_right_frame, from_=145, to=0, orient="vertical", length=180, command=self.update_values)
        self.output_right_fader.pack(expand=True)

        self.output_right_val = ttk.Label(output_box, text="0")
        self.output_right_val.grid(row=1, column=1, pady=(4,10))

        # Right side checkbuttons
        right_button_frame = ttk.Frame(main_frame)
        right_button_frame.grid(row=0, column=1, sticky="n", padx=(20,0))

        self.monitor_var = tk.BooleanVar()
        self.monitor_button = ttk.Checkbutton(right_button_frame, text="Monitor Enable", variable=self.monitor_var, command=self.toggle_monitor)
        self.monitor_button.grid(row=0, column=0, pady=(0,10), sticky="w")

        self.headphone_var = tk.BooleanVar()
        self.headphone_button = ttk.Checkbutton(right_button_frame, text="Headphone Enable", variable=self.headphone_var, command=self.toggle_headphone)
        self.headphone_button.grid(row=1, column=0, pady=(0,10), sticky="w")

        self.input_link_var = tk.BooleanVar()
        self.input_link_button = ttk.Checkbutton(right_button_frame, text="Link Inputs", variable=self.input_link_var)
        self.input_link_button.grid(row=2, column=0, pady=(0,10), sticky="w")

        self.output_link_var = tk.BooleanVar()
        self.output_link_button = ttk.Checkbutton(right_button_frame, text="Link Outputs", variable=self.output_link_var)
        self.output_link_button.grid(row=3, column=0, sticky="w")

        self.reset_button = ttk.Button(right_button_frame, text="Reset", command=self.reset_values)
        self.reset_button.grid(row=4, column=0, pady=(10,0), sticky="w")

        self.input_buttons = {
            'line': self.line_button,
            'mc': self.mc_button,
            'mm': self.mm_button,
            'mute': self.mute_button
        }

        self.selected_input = None

        self.load_defaults()

        self.input_left_fader.bind("<ButtonRelease-1>", self.on_input_left_change)
        self.input_right_fader.bind("<ButtonRelease-1>", self.on_input_right_change)
        self.output_left_fader.bind("<ButtonRelease-1>", self.on_output_left_change)
        self.output_right_fader.bind("<ButtonRelease-1>", self.on_output_right_change)

        # Bind Ctrl+P to toggle verbose window
        self.bind_all("<Control-p>", self.toggle_verbose)

        self.update()
        w = self.winfo_reqwidth()
        h = self.winfo_reqheight()
        self.geometry(f"{w}x{h}")

    def log(self, message):
        if self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_text.configure(state='normal')
            self.verbose_text.insert('end', message + "\n")
            self.verbose_text.see('end')
            self.verbose_text.configure(state='disabled')

    def send_command(self, command):
        full_command = ['phono-control'] + command.split()
        self.log(f"Running command: {' '.join(full_command)}")
        try:
            result = subprocess.run(full_command, capture_output=True, text=True)
            if result.stdout:
                self.log("Output: " + result.stdout.strip())
            if result.stderr:
                self.log("Error: " + result.stderr.strip())
        except Exception as e:
            self.log(f"Failed to run command: {e}")

    def select_input(self, input_name):
        if self.selected_input == input_name:
            return
        self.selected_input = input_name
        for name, btn in self.input_buttons.items():
            btn.config(style="Selected.TButton" if name == input_name else "TButton")
        self.send_command(f"-c {input_name}")

    def update_values(self, event=None):
        self.input_left_val.config(text=f"{int(round(self.input_left_fader.get()))}")
        self.input_right_val.config(text=f"{int(round(self.input_right_fader.get()))}")
        self.output_left_val.config(text=f"{int(round(self.output_left_fader.get()))}")
        self.output_right_val.config(text=f"{int(round(self.output_right_fader.get()))}")

    def on_input_left_change(self, event):
        val = int(round(self.input_left_fader.get()))
        if self.input_link_var.get():
            self.input_right_fader.set(val)
            val_right = val
            command = f"-l {val} -r {val_right}"
        else:
            command = f"-l {val}"
        self.send_command(command)
        self.update_values()

    def on_input_right_change(self, event):
        val = int(round(self.input_right_fader.get()))
        if self.input_link_var.get():
            self.input_left_fader.set(val)
            val_left = val
            command = f"-l {val_left} -r {val}"
        else:
            command = f"-r {val}"
        self.send_command(command)
        self.update_values()

    def on_output_left_change(self, event):
        val = int(round(self.output_left_fader.get()))
        if self.output_link_var.get():
            self.output_right_fader.set(val)
            val_right = val
            command = f"-L {val} -R {val_right}"
        else:
            command = f"-L {val}"
        self.send_command(command)
        self.update_values()

    def on_output_right_change(self, event):
        val = int(round(self.output_right_fader.get()))
        if self.output_link_var.get():
            self.output_left_fader.set(val)
            val_left = val
            command = f"-L {val_left} -R {val}"
        else:
            command = f"-R {val}"
        self.send_command(command)
        self.update_values()

    def toggle_monitor(self):
        if self.monitor_var.get():
            self.send_command("-M")
        else:
            self.send_command("-m")

    def toggle_headphone(self):
        if self.headphone_var.get():
            self.send_command("-i")
        else:
            self.send_command("-I")

    def toggle_verbose(self, event=None):
        if self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_window.destroy()
            self.verbose_window = None
        else:
            self.verbose_window = tk.Toplevel(self)
            self.verbose_window.title("Verbose Output")
            # Position verbose window beneath main window
            main_x = self.winfo_x()
            main_y = self.winfo_y()
            main_width = self.winfo_width()
            main_height = self.winfo_height()
            verbose_height = max(main_height // 2, 150)
            self.verbose_window.geometry(f"{main_width}x{verbose_height}+{main_x}+{main_y + main_height}")

            self.verbose_text = tk.Text(self.verbose_window, state='disabled', wrap='word')
            self.verbose_text.pack(fill='both', expand=True)
            self.verbose_window.protocol("WM_DELETE_WINDOW", self.on_verbose_close)

    def on_verbose_close(self):
        if self.verbose_window:
            self.verbose_window.destroy()
            self.verbose_window = None

    def reset_values(self):
        self.send_command("-d")
        self.load_defaults()

    def load_defaults(self):
        config_path = os.path.expanduser("~/phonorama_config.json")
        if not os.path.exists(config_path):
            self.log(f"Config file not found: {config_path}")
            # Set sane defaults if missing
            self.select_input('line')
            self.input_left_fader.set(0)
            self.input_right_fader.set(0)
            self.output_left_fader.set(0)
            self.output_right_fader.set(0)
            self.monitor_var.set(False)
            self.headphone_var.set(False)
            self.update_values()
            return

        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            # Map input_channel integer to input name string
            channel_map = {1: 'line', 2: 'mc', 3: 'mm', 4: 'mute'}
            input_channel = config.get("input_channel", 1)
            self.select_input(channel_map.get(input_channel, 'line'))

            self.input_left_fader.set(config.get("input_l", 0))
            self.input_right_fader.set(config.get("input_r", 0))
            self.output_left_fader.set(config.get("output_l", 0))
            self.output_right_fader.set(config.get("output_r", 0))

            self.monitor_var.set(bool(config.get("monitor_enabled", 0)))
            self.headphone_var.set(bool(config.get("headphone_enabled", 0)))

            self.update_values()
        except Exception as e:
            self.log(f"Failed to load config: {e}")
            # Fallback defaults
            self.select_input('line')
            self.input_left_fader.set(0)
            self.input_right_fader.set(0)
            self.output_left_fader.set(0)
            self.output_right_fader.set(0)
            self.monitor_var.set(False)
            self.headphone_var.set(False)
            self.update_values()

if __name__ == "__main__":
    app = PhonoControlGUI()
    app.mainloop()
