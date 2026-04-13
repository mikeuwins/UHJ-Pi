import customtkinter as ctk
import tkinter.messagebox
import subprocess
import json
import os

ctk.set_appearance_mode("light")
ctk.set_default_color_theme("blue")

# --- Helper functions ---
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

class PhonoControlApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Phonorama Control")
        self.geometry("700x400")
        self.resizable(False, False)

        self.selected_input = "line"

        self.create_widgets()
        self.load_defaults()

    def create_widgets(self):
        # Left side input buttons
        self.left_panel = ctk.CTkFrame(self, width=120)
        self.left_panel.pack(side="left", fill="y", padx=10, pady=10)

        for name in [("LINE", "line"), ("MC", "mc"), ("MM", "mm"), ("MUTE", "mute")]:
            btn = ctk.CTkButton(self.left_panel, text=name[0], command=lambda n=name[1]: self.select_input(n))
            btn.pack(pady=5, fill="x")

        self.monitor = ctk.CTkCheckBox(self.left_panel, text="Monitor", command=self.toggle_monitor)
        self.monitor.pack(pady=10)

        self.headphone = ctk.CTkCheckBox(self.left_panel, text="Headphone", command=self.toggle_headphone)
        self.headphone.pack()

        # Right side main controls
        self.right_panel = ctk.CTkFrame(self)
        self.right_panel.pack(side="left", expand=True, fill="both", padx=10, pady=10)

        self.fader_frames = []
        for label, is_input in [("Input Volume", True), ("Output Volume", False)]:
            fader_frame = ctk.CTkFrame(self.right_panel)
            fader_frame.pack(side="top", fill="x", pady=10)

            ctk.CTkLabel(fader_frame, text=label, font=("Arial", 14)).pack()

            inner = ctk.CTkFrame(fader_frame)
            inner.pack()

            val_l = ctk.CTkLabel(inner, text="0.0 dB")
            val_l.pack(side="left", padx=10)

            scale_l = ctk.CTkSlider(inner, from_=127 if is_input else 145, to=0, orientation="vertical",
                                    command=lambda v, i=is_input, l=True: self.update_fader(v, i, l))
            scale_l.set(0)
            scale_l.pack(side="left", padx=10)

            scale_r = ctk.CTkSlider(inner, from_=127 if is_input else 145, to=0, orientation="vertical",
                                    command=lambda v, i=is_input, l=False: self.update_fader(v, i, l))
            scale_r.set(0)
            scale_r.pack(side="left", padx=10)

            val_r = ctk.CTkLabel(inner, text="0.0 dB")
            val_r.pack(side="left", padx=10)

            self.fader_frames.append(((scale_l, val_l), (scale_r, val_r)))

        # Link and Reset
        bottom = ctk.CTkFrame(self.right_panel)
        bottom.pack(side="bottom", fill="x", pady=10)

        self.link_inputs = ctk.CTkCheckBox(bottom, text="Link Inputs")
        self.link_inputs.pack(side="left", padx=10)

        self.link_outputs = ctk.CTkCheckBox(bottom, text="Link Outputs")
        self.link_outputs.pack(side="left", padx=10)

        reset = ctk.CTkButton(bottom, text="Reset", command=self.reset_all)
        reset.pack(side="right", padx=10)

    def update_fader(self, val, is_input, is_left):
        val = float(val)
        snap_func = snap_input_raw if is_input else snap_output_raw
        label_func = input_value_to_db if is_input else output_value_to_db
        raw = snap_func(val)
        db = label_func(raw)
        index = 0 if is_input else 1
        fader = self.fader_frames[index][0 if is_left else 1]
        fader[0].set(raw)
        fader[1].configure(text=db)

        if (is_input and self.link_inputs.get()) or (not is_input and self.link_outputs.get()):
            other_fader = self.fader_frames[index][1 if is_left else 0]
            other_fader[0].set(raw)
            other_fader[1].configure(text=db)

    def select_input(self, name):
        self.selected_input = name
        self.run_command(f"-c {name}")

    def toggle_monitor(self):
        self.run_command("-M" if self.monitor.get() else "-m")

    def toggle_headphone(self):
        self.run_command("-i" if self.headphone.get() else "-I")

    def reset_all(self):
        self.run_command("-d")
        self.load_defaults()

    def run_command(self, command):
        try:
            subprocess.run(["phono-control"] + command.split(), capture_output=True)
        except Exception as e:
            print("Error:", e)

    def load_defaults(self):
        try:
            path = os.path.expanduser("~/phonorama_config.json")
            if os.path.exists(path):
                with open(path) as f:
                    config = json.load(f)
                self.select_input({1: "line", 2: "mc", 3: "mm", 4: "mute"}.get(config.get("input_channel", 1), "line"))
                self.fader_frames[0][0][0].set(config.get("input_l", 88))
                self.fader_frames[0][1][0].set(config.get("input_r", 88))
                self.fader_frames[1][0][0].set(config.get("output_l", 145))
                self.fader_frames[1][1][0].set(config.get("output_r", 145))
        except Exception as e:
            print("Failed to load config:", e)

if __name__ == "__main__":
    app = PhonoControlApp()
    app.mainloop()
