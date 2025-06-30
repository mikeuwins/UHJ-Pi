import tkinter as tk
from tkinter import ttk
import subprocess
import json
import os

# --- dB conversion helpers ---
def input_value_to_db(value):
    db = -40 + (value / 127) * 52
    return f"{db:.1f} dB"

def output_value_to_db(value):
    db = -55 + (value / 145) * 55
    return f"{db:.1f} dB"

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
        self.configure(padx=8, pady=8)

        self.verbose_window = None

        self.style = ttk.Style()
        self.style.configure("TButton", padding=3)
        self.style.map("Selected.TButton", background=[("active", "#80b3ff"), ("!active", "#cce6ff")])

        self.value_font = ("TkDefaultFont", 9)

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

        main_frame = ttk.Frame(self)
        main_frame.grid(row=0, column=1, sticky="nsew", padx=10)

        faders_frame = ttk.Frame(main_frame)
        faders_frame.grid(row=0, column=0, sticky="nw")

        input_box = ttk.LabelFrame(faders_frame, text="Input Volume", labelanchor='n')
        input_box.grid(row=0, column=0, padx=(8,20), sticky="n")
        input_box.columnconfigure((0,1), weight=1)

        input_left_frame = ttk.Frame(input_box, width=70)
        input_left_frame.grid(row=0, column=0, padx=8, pady=(12,0))
        input_left_frame.grid_propagate(False)

        self.input_left_fader = ttk.Scale(input_left_frame, from_=127, to=0, orient="vertical", length=220, command=self.update_values)
        self.input_left_fader.pack(expand=True)
        self.input_left_fader.bind("<ButtonRelease-1>", self.on_input_left_release)

        self.input_left_val = ttk.Label(input_box, text="0", width=9, anchor="center", font=self.value_font)
        self.input_left_val.grid(row=1, column=0, pady=(4,10), sticky="ew")

        input_right_frame = ttk.Frame(input_box, width=70)
        input_right_frame.grid(row=0, column=1, padx=8, pady=(12,0))
        input_right_frame.grid_propagate(False)

        self.input_right_fader = ttk.Scale(input_right_frame, from_=127, to=0, orient="vertical", length=220, command=self.update_values)
        self.input_right_fader.pack(expand=True)
        self.input_right_fader.bind("<ButtonRelease-1>", self.on_input_right_release)

        self.input_right_val = ttk.Label(input_box, text="0", width=9, anchor="center", font=self.value_font)
        self.input_right_val.grid(row=1, column=1, pady=(4,10), sticky="ew")

        output_box = ttk.LabelFrame(faders_frame, text="Output Volume", labelanchor='n')
        output_box.grid(row=0, column=1, sticky="n")
        output_box.columnconfigure((0,1), weight=1)

        output_left_frame = ttk.Frame(output_box, width=70)
        output_left_frame.grid(row=0, column=0, padx=8, pady=(12,0))
        output_left_frame.grid_propagate(False)

        self.output_left_fader = ttk.Scale(output_left_frame, from_=145, to=0, orient="vertical", length=220, command=self.update_values)
        self.output_left_fader.pack(expand=True)
        self.output_left_fader.bind("<ButtonRelease-1>", self.on_output_left_release)

        self.output_left_val = ttk.Label(output_box, text="0", width=9, anchor="center", font=self.value_font)
        self.output_left_val.grid(row=1, column=0, pady=(4,10), sticky="ew")

        output_right_frame = ttk.Frame(output_box, width=70)
        output_right_frame.grid(row=0, column=1, padx=8, pady=(12,0))
        output_right_frame.grid_propagate(False)

        self.output_right_fader = ttk.Scale(output_right_frame, from_=145, to=0, orient="vertical", length=220, command=self.update_values)
        self.output_right_fader.pack(expand=True)
        self.output_right_fader.bind("<ButtonRelease-1>", self.on_output_right_release)

        self.output_right_val = ttk.Label(output_box, text="0", width=9, anchor="center", font=self.value_font)
        self.output_right_val.grid(row=1, column=1, pady=(4,10), sticky="ew")

    def update_values(self, event=None):
        self.input_left_val.config(text=input_value_to_db(float(self.input_left_fader.get())))
        self.input_right_val.config(text=input_value_to_db(float(self.input_right_fader.get())))
        self.output_left_val.config(text=output_value_to_db(float(self.output_left_fader.get())))
        self.output_right_val.config(text=output_value_to_db(float(self.output_right_fader.get())))

    def on_input_left_release(self, event):
        raw = snap_input_raw(float(self.input_left_fader.get()))
        self.input_left_fader.set(raw)
        self.input_left_val.config(text=input_value_to_db(raw))

    def on_input_right_release(self, event):
        raw = snap_input_raw(float(self.input_right_fader.get()))
        self.input_right_fader.set(raw)
        self.input_right_val.config(text=input_value_to_db(raw))

    def on_output_left_release(self, event):
        raw = snap_output_raw(float(self.output_left_fader.get()))
        self.output_left_fader.set(raw)
        self.output_left_val.config(text=output_value_to_db(raw))

    def on_output_right_release(self, event):
        raw = snap_output_raw(float(self.output_right_fader.get()))
        self.output_right_fader.set(raw)
        self.output_right_val.config(text=output_value_to_db(raw))

if __name__ == "__main__":
    app = PhonoControlGUI()
    app.mainloop()
