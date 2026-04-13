import tkinter as tk
from tkinter import ttk
import subprocess
import json
import os

# --- dB conversion helpers ---
def input_value_to_db(value):
    db = -40 + (value / 127) * 52
    db = round(db * 2) / 2
    return f"{db:+.1f} dB"

def output_value_to_db(value):
    db = -55 + (value / 145) * 55
    db = round(db * 2) / 2
    return f"{db:+.1f} dB"

def snap_input_raw(value):
    db = -40 + (value / 127) * 52
    db_snapped = round(db * 2) / 2
    return round((db_snapped + 40) / 52 * 127)

def snap_output_raw(value):
    db = -55 + (value / 145) * 55
    db_snapped = round(db * 2) / 2
    return round((db_snapped + 55) / 55 * 145)

class PhonoControlGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Phono Control GUI")
        self.configure(padx=12, pady=12)
        self.style = ttk.Style(self)

        # Configure custom styles
        self.style.configure("TButton", padding=4, relief="raised")
        self.style.configure("Selected.TButton", background="#3399ff", foreground="white")

        self.value_font = ("Courier", 10, "bold")

        self.input_buttons = {}
        self.selected_input = None

        self.create_widgets()
        self.bind_all("<Control-p>", self.toggle_verbose)

    def create_widgets(self):
        main_frame = ttk.Frame(self)
        main_frame.grid(row=0, column=0)

        left_buttons = ttk.Frame(main_frame)
        left_buttons.grid(row=0, column=0, padx=(0, 10), sticky="ns")

        for idx, label in enumerate(["Line In", "MC", "MM", "Mute"]):
            key = label.lower().replace(" ", "")
            btn = ttk.Button(left_buttons, text=label, width=10, command=lambda k=key: self.select_input(k))
            btn.grid(row=idx, column=0, pady=3, sticky="ew")
            self.input_buttons[key] = btn

        fader_frame = ttk.Frame(main_frame)
        fader_frame.grid(row=0, column=1)

        self.create_fader_group(fader_frame, "Input", 127, input_value_to_db, snap_input_raw, 0)
        self.create_fader_group(fader_frame, "Output", 145, output_value_to_db, snap_output_raw, 1)

        right_controls = ttk.Frame(main_frame)
        right_controls.grid(row=0, column=2, padx=(20,0), sticky="n")

        self.monitor_var = tk.BooleanVar()
        self.headphone_var = tk.BooleanVar()
        self.link_input_var = tk.BooleanVar()
        self.link_output_var = tk.BooleanVar()

        ttk.Checkbutton(right_controls, text="Monitor Enable", variable=self.monitor_var, command=self.toggle_monitor).grid(sticky="w", pady=2)
        ttk.Checkbutton(right_controls, text="Headphone Enable", variable=self.headphone_var, command=self.toggle_headphone).grid(sticky="w", pady=2)
        ttk.Checkbutton(right_controls, text="Link Inputs", variable=self.link_input_var).grid(sticky="w", pady=2)
        ttk.Checkbutton(right_controls, text="Link Outputs", variable=self.link_output_var).grid(sticky="w", pady=2)

        ttk.Button(right_controls, text="Reset", command=self.reset_values).grid(sticky="ew", pady=(10, 0))

    def create_fader_group(self, parent, title, scale_max, db_func, snap_func, col):
        box = ttk.LabelFrame(parent, text=title.upper(), labelanchor="n")
        box.grid(row=0, column=col, padx=10)

        for i, ch in enumerate(["Left", "Right"]):
            frame = ttk.Frame(box, width=60)
            frame.grid(row=0, column=i, padx=8, pady=8)
            frame.grid_propagate(False)

            scale = ttk.Scale(frame, from_=scale_max, to=0, orient="vertical", length=200)
            scale.pack(expand=True)

            label = tk.Label(box, text="0.0 dB", width=9, bg="black", fg="white", relief="sunken", font=self.value_font)
            label.grid(row=1, column=i, pady=(4,10))

            scale.bind("<B1-Motion>", lambda e, s=scale, l=label, d=db_func: l.config(text=d(s.get())))
            scale.bind("<ButtonRelease-1>", lambda e, s=scale, l=label, f=snap_func, d=db_func: self.snap_slider(s, l, f, d))

            if title == "Input":
                if ch == "Left":
                    self.input_left_fader, self.input_left_label = scale, label
                else:
                    self.input_right_fader, self.input_right_label = scale, label
            else:
                if ch == "Left":
                    self.output_left_fader, self.output_left_label = scale, label
                else:
                    self.output_right_fader, self.output_right_label = scale, label

    def snap_slider(self, scale, label, snap_func, db_func):
        val = snap_func(scale.get())
        scale.set(val)
        label.config(text=db_func(val))

    def select_input(self, name):
        if self.selected_input == name:
            return
        self.selected_input = name
        for k, b in self.input_buttons.items():
            b.config(style="Selected.TButton" if k == name else "TButton")
        self.send_command(f"-c {name}")

    def toggle_monitor(self):
        self.send_command("-M" if self.monitor_var.get() else "-m")

    def toggle_headphone(self):
        self.send_command("-i" if self.headphone_var.get() else "-I")

    def reset_values(self):
        self.send_command("-d")

    def send_command(self, cmd):
        full = ["phono-control"] + cmd.split()
        try:
            subprocess.run(full, capture_output=True)
        except Exception as e:
            print("Error:", e)

    def toggle_verbose(self, event=None):
        if hasattr(self, 'verbose_window') and self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_window.destroy()
            self.verbose_window = None
        else:
            self.verbose_window = tk.Toplevel(self)
            self.verbose_window.title("Verbose Output")
            self.verbose_text = tk.Text(self.verbose_window, wrap='word', state='disabled')
            self.verbose_text.pack(fill='both', expand=True)

if __name__ == "__main__":
    app = PhonoControlGUI()
    app.mainloop()
