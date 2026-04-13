import tkinter as tk
from tkinter import ttk
import subprocess
import threading
import queue
import json
import os

def input_value_to_db(value):
    db = -40 + (value / 127) * 52
    return f"{db:.1f} dB"

def output_value_to_db(value):
    db = -55 + (value / 145) * 55
    return f"{db:.1f} dB"

class PhonoControlGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Phono Control GUI")
        self.configure(padx=8, pady=8)
        # [ initialization code remains unchanged ]

    def update_values(self, event=None):
        input_left_val = int(round(self.input_left_fader.get()))
        input_right_val = int(round(self.input_right_fader.get()))
        output_left_val = int(round(self.output_left_fader.get()))
        output_right_val = int(round(self.output_right_fader.get()))

        self.input_left_val.config(text=input_value_to_db(input_left_val))
        self.input_right_val.config(text=input_value_to_db(input_right_val))
        self.output_left_val.config(text=output_value_to_db(output_left_val))
        self.output_right_val.config(text=output_value_to_db(output_right_val))

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

    def log(self, message):
        if self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_text.configure(state='normal')
            self.verbose_text.insert('end', message + "\n")
            self.verbose_text.see('end')
            self.verbose_text.configure(state='disabled')

    def load_defaults(self):
        config_path = os.path.expanduser("~/phonorama_config.json")
        if not os.path.exists(config_path):
            self.log(f"Config file not found: {config_path}")
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
