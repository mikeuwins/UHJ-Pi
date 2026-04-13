import tkinter as tk
from tkinter import ttk
import subprocess
import threading
import queue

class PhonoControlGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Phono Control GUI")
        self.configure(padx=8, pady=8)

        # Initialize verbose window attribute
        self.verbose_window = None

        # Start CLI process
        self.cli_process = subprocess.Popen(
            ['phono-control'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1
        )

        # Queue for CLI output
        self.cli_queue = queue.Queue()
        self.cli_thread = threading.Thread(target=self.read_cli_output, daemon=True)
        self.cli_thread.start()

        # Style for highlighting selected input button
        self.style = ttk.Style()
        self.style.configure("TButton", padding=3)
        self.style.map("Selected.TButton", background=[("active", "#80b3ff"), ("!active", "#cce6ff")])

        # Left buttons frame
        button_frame = ttk.Frame(self)
        button_frame.grid(row=0, column=0, sticky="ns")

        self.line_button = ttk.Button(button_frame, text="LINE", width=8, command=lambda: self.select_input('LINE'))
        self.line_button.grid(row=0, column=0, pady=(0,4), sticky="ew")

        self.mc_button = ttk.Button(button_frame, text="MC", width=8, command=lambda: self.select_input('MC'))
        self.mc_button.grid(row=1, column=0, pady=4, sticky="ew")

        self.mm_button = ttk.Button(button_frame, text="MM", width=8, command=lambda: self.select_input('MM'))
        self.mm_button.grid(row=2, column=0, pady=4, sticky="ew")

        button_frame.rowconfigure(3, weight=1)

        self.mute_button = ttk.Button(button_frame, text="MUTE", width=8, command=lambda: self.select_input('MUTE'))
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

        # Remove verbose checkbox as per your request

        self.reset_button = ttk.Button(right_button_frame, text="Reset", command=self.reset_values)
        self.reset_button.grid(row=4, column=0, pady=(10,0), sticky="w")

        # Remove restart CLI button as per your request

        self.input_buttons = {
            'LINE': self.line_button,
            'MC': self.mc_button,
            'MM': self.mm_button,
            'MUTE': self.mute_button
        }

        self.selected_input = None
        self.select_input('LINE')

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

        self.after(100, self.process_cli_queue)

        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def log(self, message):
        if self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_text.configure(state='normal')
            self.verbose_text.insert('end', message + "\n")
            self.verbose_text.see('end')
            self.verbose_text.configure(state='disabled')

    def send_command(self, command):
        self.log(f"phono-control {command}")
        if self.cli_process.poll() is None:
            try:
                self.cli_process.stdin.write(command + "\n")
                self.cli_process.stdin.flush()
            except BrokenPipeError:
                self.log("Error: Broken pipe - CLI process not running")
        else:
            self.log("Error: CLI process not running")

    def read_cli_output(self):
        for line in self.cli_process.stdout:
            self.cli_queue.put(line.strip())

    def process_cli_queue(self):
        try:
            while True:
                line = self.cli_queue.get_nowait()
                self.log(f"CLI: {line}")
        except queue.Empty:
            pass
        self.after(100, self.process_cli_queue)

    def select_input(self, input_name):
        if self.selected_input == input_name:
            return
        self.selected_input = input_name
        for name, btn in self.input_buttons.items():
            btn.config(style="Selected.TButton" if name == input_name else "TButton")
        self.send_command(f"-c {input_name.lower()}")

    def update_values(self, event=None):
        self.input_left_val.config(text=f"{int(round(self.input_left_fader.get()))}")
        self.input_right_val.config(text=f"{int(round(self.input_right_fader.get()))}")
        self.output_left_val.config(text=f"{int(round(self.output_left_fader.get()))}")
        self.output_right_val.config(text=f"{int(round(self.output_right_fader.get()))}")

    def on_input_left_change(self, event):
        val = int(round(self.input_left_fader.get()))
        if self.input_link_var.get():
            self.input_right_fader.set(val)
        self.send_command(f"-l {val}")
        self.update_values()

    def on_input_right_change(self, event):
        val = int(round(self.input_right_fader.get()))
        if self.input_link_var.get():
            self.input_left_fader.set(val)
        self.send_command(f"-r {val}")
        self.update_values()

    def on_output_left_change(self, event):
        val = int(round(self.output_left_fader.get()))
        if self.output_link_var.get():
            self.output_right_fader.set(val)
        self.send_command(f"-L {val}")
        self.update_values()

    def on_output_right_change(self, event):
        val = int(round(self.output_right_fader.get()))
        if self.output_link_var.get():
            self.output_left_fader.set(val)
        self.send_command(f"-R {val}")
        self.update_values()

    def toggle_monitor(self):
        state = 'on' if self.monitor_var.get() else 'off'
        self.send_command(f"monitor {state}")

    def toggle_headphone(self):
        state = 'on' if self.headphone_var.get() else 'off'
        self.send_command(f"headphone {state}")

    def toggle_verbose(self, event=None):
        if self.verbose_window and self.verbose_window.winfo_exists():
            self.verbose_window.destroy()
            self.verbose_window = None
        else:
            self.verbose_window = tk.Toplevel(self)
            self.verbose_window.title("Verbose Output")
            self.verbose_window.geometry("600x300")
            self.verbose_text = tk.Text(self.verbose_window, state='disabled', wrap='word')
            self.verbose_text.pack(fill='both', expand=True)
            # Optional: handle closing verbose window via 'X' button
            self.verbose_window.protocol("WM_DELETE_WINDOW", self.on_verbose_close)

    def on_verbose_close(self):
        if self.verbose_window:
            self.verbose_window.destroy()
            self.verbose_window = None

    def reset_values(self):
        self.input_left_fader.set(0)
        self.input_right_fader.set(0)
        self.output_left_fader.set(0)
        self.output_right_fader.set(0)
        self.update_values()
        self.send_command("reset")

    def on_close(self):
        self.cli_process.terminate()
        self.cli_process.wait()
        self.destroy()

if __name__ == "__main__":
    app = PhonoControlGUI()
    app.mainloop()
