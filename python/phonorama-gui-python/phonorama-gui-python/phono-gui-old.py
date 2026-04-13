import tkinter as tk
from tkinter import ttk
import subprocess

CLI_CMD = 'phono-control'

class PhonoControlGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Phono Control GUI")
        self.configure(padx=5, pady=5)

        # State
        self.selected_input = None
        self.mute_enabled = False
        self.link_inputs = tk.BooleanVar(value=False)
        self.link_outputs = tk.BooleanVar(value=False)
        self._updating = False  # guard against recursive updates

        # Store default bg color
        temp_btn = tk.Button(self)
        self.default_bg = temp_btn.cget('bg')
        temp_btn.destroy()

        # Left panel for input selection and mute
        button_frame = ttk.Frame(self)
        button_frame.grid(row=0, column=0, sticky="ns")

        # Input selection buttons
        self.line_button = tk.Button(button_frame, text="LINE", width=12,
                                     command=lambda: self.select_input('line'))
        self.line_button.grid(row=0, column=0, pady=(0,5), sticky="ew")

        self.mc_button = tk.Button(button_frame, text="MC", width=12,
                                   command=lambda: self.select_input('mc'))
        self.mc_button.grid(row=1, column=0, pady=5, sticky="ew")

        self.mm_button = tk.Button(button_frame, text="MM", width=12,
                                   command=lambda: self.select_input('mm'))
        self.mm_button.grid(row=2, column=0, pady=5, sticky="ew")

        # Spacer
        button_frame.rowconfigure(3, weight=1)

        # Mute button
        self.mute_button = tk.Button(button_frame, text="MUTE", width=12,
                                     command=self.toggle_mute)
        self.mute_button.grid(row=4, column=0, pady=(5,0), sticky="ew")

        # Main frame for faders and toggles
        main_frame = ttk.Frame(self)
        main_frame.grid(row=0, column=1, sticky="nw", padx=10)

        # Input Volume (0-127)
        input_box = ttk.LabelFrame(main_frame, text="Input Volume", labelanchor='n')
        input_box.grid(row=0, column=0, padx=(0,10), pady=5, sticky="nw")
        input_box.grid_columnconfigure((0,1), weight=1)

        self.input_left_fader = ttk.Scale(input_box, from_=127, to=0, orient="vertical",
                                           length=160, command=self.on_input_left)
        self.input_left_fader.grid(row=0, column=0, padx=5, pady=(10,2))
        self.input_right_fader = ttk.Scale(input_box, from_=127, to=0, orient="vertical",
                                            length=160, command=self.on_input_right)
        self.input_right_fader.grid(row=0, column=1, padx=5, pady=(10,2))

        self.input_left_val = tk.Label(input_box, text="0")
        self.input_left_val.grid(row=1, column=0, pady=(0,5))
        self.input_right_val = tk.Label(input_box, text="0")
        self.input_right_val.grid(row=1, column=1, pady=(0,5))

        # Output Volume (0-145)
        output_box = ttk.LabelFrame(main_frame, text="Output Volume", labelanchor='n')
        output_box.grid(row=0, column=1, padx=(10,0), pady=5, sticky="nw")
        output_box.grid_columnconfigure((0,1), weight=1)

        self.output_left_fader = ttk.Scale(output_box, from_=145, to=0, orient="vertical",
                                            length=160, command=self.on_output_left)
        self.output_left_fader.grid(row=0, column=0, padx=5, pady=(10,2))
        self.output_right_fader = ttk.Scale(output_box, from_=145, to=0, orient="vertical",
                                             length=160, command=self.on_output_right)
        self.output_right_fader.grid(row=0, column=1, padx=5, pady=(10,2))

        self.output_left_val = tk.Label(output_box, text="0")
        self.output_left_val.grid(row=1, column=0, pady=(0,5))
        self.output_right_val = tk.Label(output_box, text="0")
        self.output_right_val.grid(row=1, column=1, pady=(0,5))

        # Toggles
        toggle_frame = ttk.Frame(main_frame)
        toggle_frame.grid(row=0, column=2, sticky="nw", padx=(20,0))  # moved right

        self.link_check = ttk.Checkbutton(toggle_frame, text="Link Inputs",
                                          variable=self.link_inputs)
        self.link_check.pack(pady=(20,5), anchor="w")

        self.link_out_check = ttk.Checkbutton(toggle_frame, text="Link Outputs",
                                              variable=self.link_outputs)
        self.link_out_check.pack(pady=(0,5), anchor="w")

        self.monitor_var = tk.BooleanVar()
        self.monitor_button = ttk.Checkbutton(toggle_frame, text="Monitor Enable",
                                              variable=self.monitor_var,
                                              command=self.on_monitor)
        self.monitor_button.pack(pady=5, anchor="w")

        self.headphone_var = tk.BooleanVar()
        self.headphone_button = ttk.Checkbutton(toggle_frame, text="Headphone Enable",
                                                  variable=self.headphone_var,
                                                  command=self.on_headphone)
        self.headphone_button.pack(pady=5, anchor="w")

        # CLI output text box
        output_frame = ttk.Frame(self)
        output_frame.grid(row=1, column=0, columnspan=3, sticky="we", pady=(10,0))
        self.cli_output = tk.Text(output_frame, height=6, wrap="none")
        self.cli_output.pack(fill="both", expand=True)

        # Finalize layout and minimize window size
        self.update_idletasks()
        self.geometry(f"{self.winfo_reqwidth() - 30}x{self.winfo_reqheight()}")  # shrink width
        self.minsize(self.winfo_width(), self.winfo_height())

    def run_cli(self, args):
        try:
            result = subprocess.run([CLI_CMD] + args, capture_output=True, text=True)
            output = result.stdout + result.stderr
        except Exception as e:
            output = str(e)
        self.cli_output.insert('end', f"$ {CLI_CMD} {' '.join(args)}\n")
        self.cli_output.insert('end', output + "\n")
        self.cli_output.see('end')

    def select_input(self, mode):
        if self.mute_enabled:
            self.toggle_mute()
        for btn in (self.line_button, self.mc_button, self.mm_button):
            btn.configure(bg=self.default_bg)
        mapping = {'line': self.line_button, 'mc': self.mc_button, 'mm': self.mm_button}
        mapping[mode].configure(bg="lightblue")
        self.selected_input = mode
        self.run_cli(['-c', mode])

    def toggle_mute(self):
        if self.selected_input:
            for btn in (self.line_button, self.mc_button, self.mm_button):
                btn.configure(bg=self.default_bg)
            self.selected_input = None
        self.mute_enabled = not self.mute_enabled
        self.mute_button.configure(bg="lightblue" if self.mute_enabled else self.default_bg)
        self.run_cli(['-c', 'mute'])

    def on_input_left(self, val):
        v = int(round(float(val)))
        if self.link_inputs.get() and not self._updating:
            self._updating = True
            self.input_right_fader.set(v)
            self.input_right_val.config(text=str(v))
            self._updating = False
        self.input_left_val.config(text=str(v))
        self.run_cli(['-l', str(v)])

    def on_input_right(self, val):
        v = int(round(float(val)))
        if self.link_inputs.get() and not self._updating:
            self._updating = True
            self.input_left_fader.set(v)
            self.input_left_val.config(text=str(v))
            self._updating = False
        self.input_right_val.config(text=str(v))
        self.run_cli(['-r', str(v)])

    def on_output_left(self, val):
        v = int(round(float(val)))
        if self.link_outputs.get() and not self._updating:
            self._updating = True
            self.output_right_fader.set(v)
            self.output_right_val.config(text=str(v))
            self._updating = False
        self.output_left_val.config(text=str(v))
        self.run_cli(['-L', str(v)])

    def on_output_right(self, val):
        v = int(round(float(val)))
        if self.link_outputs.get() and not self._updating:
            self._updating = True
            self.output_left_fader.set(v)
            self.output_left_val.config(text=str(v))
            self._updating = False
        self.output_right_val.config(text=str(v))
        self.run_cli(['-R', str(v)])

    def on_monitor(self):
        self.run_cli(['-M' if self.monitor_var.get() else '-m'])

    def on_headphone(self):
        self.run_cli(['-i' if self.headphone_var.get() else '-I'])

if __name__ == '__main__':
    app = PhonoControlGUI()
    app.mainloop()
