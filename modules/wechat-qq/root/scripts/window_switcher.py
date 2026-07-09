#!/usr/bin/env python3

import tkinter as tk
from tkinter import ttk
import threading
import time
from Xlib import X, display
from Xlib.ext import shape
import re

class Tooltip:
    def __init__(self, widget):
        self.widget = widget
        self.tipwindow = None
        self.id = None
        self.x = self.y = 0

    def showtip(self, text):
        "Display text in tooltip window"
        self.text = text
        if self.tipwindow or not self.text:
            return
        x = self.widget.winfo_rootx() + 20
        y = self.widget.winfo_rooty() + 20
        self.tipwindow = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(1)
        tw.wm_geometry("+%d+%d" % (x, y))
        label = tk.Label(tw, text=self.text, justify=tk.LEFT,
                      background="#ffffe0", relief=tk.SOLID, borderwidth=1,
                      font=("tahoma", "8", "normal"))
        label.pack(ipadx=1)

    def hidetip(self):
        tw = self.tipwindow
        self.tipwindow = None
        if tw:
            tw.destroy()

def CreateTooltip(widget, text):
    tooltip = Tooltip(widget)
    def enter(event):
        tooltip.showtip(text)
    def leave(event):
        tooltip.hidetip()
    widget.bind('<Enter>', enter)
    widget.bind('<Leave>', leave)

class WindowSwitcher:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Window Switcher")
        self.root.overrideredirect(True)  # No border
        self.root.attributes('-topmost', True)  # Always on top
        self.root.configure(bg='#2c2c2c')

        # Set up window style
        self.setup_ui()

        # Initialize window list
        self.current_windows = []
        self.buttons = []

        # Create X11 connection
        self.d = display.Display()
        self.root_win = self.d.screen().root

        # Enable event listening (with lower permission mask)
        self.enable_event_listening()

        # Initial window list
        self.update_window_list()

        # Bind drag events
        self.is_dragging = False
        self.drag_threshold = 5  # Minimum pixel movement to consider as drag
        self.start_x = 0
        self.start_y = 0
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.bind_drag_events()

    def setup_ui(self):
        # Button container
        self.button_frame = tk.Frame(self.root, bg='#2c2c2c')
        self.button_frame.pack(fill='both', expand=True, padx=1, pady=1)

    def enable_event_listening(self):
        """Enable X11 event listening (with lower permission mask)"""
        try:
            # Use PropertyChangeMask and FocusChangeMask
            self.root_win.change_attributes(
                event_mask=X.PropertyChangeMask |
                          X.FocusChangeMask
            )

            # Start event listening thread
            self.event_thread = threading.Thread(target=self.event_loop, daemon=True)
            self.event_thread.start()
        except Exception as e:
            print(f"Cannot set up event listening: {e}")
            print("Using polling mode as fallback")
            # If event listening fails, start polling thread
            self.polling_thread = threading.Thread(target=self.polling_loop, daemon=True)
            self.polling_thread.start()

    def bind_drag_events(self):
        def start_move(event):
            # Only start dragging if clicked on the background, not on a button
            if str(event.widget) == str(self.root):
                self.is_dragging = False  # Reset drag state
                self.start_x = event.x_root
                self.start_y = event.y_root
                self.drag_start_x = self.root.winfo_x()
                self.drag_start_y = self.root.winfo_y()

        def do_move(event):
            # Calculate distance moved
            current_x = event.x_root
            current_y = event.y_root
            dx = abs(current_x - self.start_x)
            dy = abs(current_y - self.start_y)

            # If movement exceeds threshold, start dragging
            if not self.is_dragging and (dx > self.drag_threshold or dy > self.drag_threshold):
                self.is_dragging = True

            if self.is_dragging:
                x = self.drag_start_x + (current_x - self.start_x)
                y = self.drag_start_y + (current_y - self.start_y)
                self.root.geometry(f"+{x}+{y}")

        def end_move(event):
            # After drag is complete, reset dragging state
            self.is_dragging = False

        # Bind events to root window
        self.root.bind("<Button-1>", start_move)
        self.root.bind("<B1-Motion>", do_move)
        self.root.bind("<ButtonRelease-1>", end_move)

    def get_current_desktop_windows(self):
        """Get all windows on current desktop (including minimized windows)"""
        try:
            # Get current desktop number
            current_desktop_prop = self.root_win.get_full_property(
                self.d.intern_atom("_NET_CURRENT_DESKTOP"), X.AnyPropertyType
            )
            current_desktop = current_desktop_prop.value[0] if current_desktop_prop else 0

            # Get current active window
            active_window_prop = self.root_win.get_full_property(
                self.d.intern_atom("_NET_ACTIVE_WINDOW"), X.AnyPropertyType
            )
            active_wid = active_window_prop.value[0] if active_window_prop else None

            # Get all client windows
            client_list_prop = self.root_win.get_full_property(
                self.d.intern_atom("_NET_CLIENT_LIST"), X.AnyPropertyType
            )
            if not client_list_prop:
                return []

            window_ids = client_list_prop.value
            windows = []

            for wid in window_ids:
                try:
                    win = self.d.create_resource_object('window', wid)

                    # Skip current active window
                    if wid == active_wid:
                        continue

                    # Get window type, exclude dock, desktop, etc.
                    wtype_prop = win.get_full_property(
                        self.d.intern_atom("_NET_WM_WINDOW_TYPE"), X.AnyPropertyType
                    )
                    if wtype_prop:
                        wtype_atoms = wtype_prop.value
                        skip_types = [
                            self.d.intern_atom("_NET_WM_WINDOW_TYPE_DOCK"),
                            self.d.intern_atom("_NET_WM_WINDOW_TYPE_DESKTOP"),
                            self.d.intern_atom("_NET_WM_WINDOW_TYPE_SPLASH"),
                            self.d.intern_atom("_NET_WM_WINDOW_TYPE_TOOLBAR"),
                            self.d.intern_atom("_NET_WM_WINDOW_TYPE_MENU")
                        ]

                        if any(atom in wtype_atoms for atom in skip_types):
                            continue

                    # Get window's desktop
                    desktop_prop = win.get_full_property(
                        self.d.intern_atom("_NET_WM_DESKTOP"), X.AnyPropertyType
                    )
                    if desktop_prop and desktop_prop.value[0] != current_desktop:
                        continue

                    # Get window name
                    name_prop = win.get_full_property(
                        self.d.intern_atom("_NET_WM_NAME"), X.AnyPropertyType
                    ) or win.get_full_property(
                        self.d.intern_atom("WM_NAME"), X.AnyPropertyType
                    )

                    title = name_prop.value.decode() if name_prop and name_prop.value else "Unknown"

                    # Check if window is minimized
                    state_prop = win.get_full_property(
                        self.d.intern_atom("_NET_WM_STATE"), X.AnyPropertyType
                    )
                    is_minimized = False
                    if state_prop:
                        state_atoms = state_prop.value
                        minimized_atom = self.d.intern_atom("_NET_WM_STATE_HIDDEN")
                        if minimized_atom in state_atoms:
                            is_minimized = True

                    # Show non-active windows (including minimized windows)
                    windows.append((wid, title, is_minimized))
                except Exception as e:
                    print(f"Error processing window {wid}: {e}")
                    continue

            # Return at most 10 windows
            return windows[:10]
        except Exception as e:
            print(f"Error getting window list: {e}")
            return []

    def update_window_list(self):
        """Update window list"""
        new_windows = self.get_current_desktop_windows()
        if new_windows != self.current_windows:
            self.current_windows = new_windows
            # Update UI in main thread
            self.root.after(0, self.refresh_ui)

    def activate_window(self, wid):
        """Activate specified window only if not dragging"""
        # Activate only if not dragging
        if not self.is_dragging:
            try:
                win = self.d.create_resource_object('window', wid)

                # Build ClientMessage event
                from Xlib.protocol import event
                atom = self.d.intern_atom("_NET_ACTIVE_WINDOW")

                # Create ClientMessage event
                msg = event.ClientMessage(
                    window=win,
                    client_type=atom,
                    data=(32, [1, X.CurrentTime, 0, 0, 0])
                )

                # Send activate window message
                self.root_win.send_event(
                    msg,
                    event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask
                )
                self.d.flush()

                # Bring window to top
                win.configure(stack_mode=X.Above)
                self.root.attributes('-topmost', True)  # Keep switcher on top
            except Exception as e:
                print(f"Error activating window: {e}")

    def get_display_text(self, title):
        """Determine display text based on character type"""
        if not title:
            return "?"

        # Check if it contains Chinese characters
        has_chinese = bool(re.search(r'[\u4e00-\u9fff]', title))

        if has_chinese:
            # If contains Chinese, show first character only
            return title[0]
        else:
            # If only English, show first 2-3 characters, but not exceeding title length
            return title[:3]

    def refresh_ui(self):
        """Refresh UI, update window list"""
        # Clear old buttons
        for btn in self.buttons:
            btn.destroy()
        self.buttons.clear()

        # Adjust window size based on number of windows
        num_windows = len(self.current_windows)
        if num_windows == 0:
            # If no windows, hide entire window
            self.root.withdraw()
        else:
            # Calculate window width (each cell 30px, plus borders and spacing)
            width = num_windows * 30 + (num_windows - 1) * 2  # 30px cell + 2px border
            self.root.geometry(f"{width}x30")
            self.root.deiconify()  # Ensure window is visible

        # Create new buttons
        for wid, title, is_minimized in self.current_windows:
            # Get text to display
            display_text = self.get_display_text(title)

            # Create fixed-size frame container
            container = tk.Frame(self.button_frame, width=30, height=30, bg='#4a4a4a')
            container.pack_propagate(False)  # Prevent container size from changing with content
            container.pack(side='left', padx=1, pady=1)

            # Create button inside container
            btn = tk.Button(
                container,
                text=display_text,
                command=lambda w=wid: self.activate_window(w),
                bg='#4a4a4a',
                fg='#ffffff',
                activebackground='#5a5a5a',
                activeforeground='#ffffff',
                relief='flat',
                font=('Arial', 10, 'bold'),
                bd=0  # No border
            )

            # Add tooltip
            CreateTooltip(btn, f"{title} {'(Minimized)' if is_minimized else ''}")

            # Fill container with button
            btn.pack(fill='both', expand=True)

            self.buttons.append(container)

    def event_loop(self):
        """Event listening loop"""
        # Event mask constants
        PROPERTY_CHANGE = 28  # X.PropertyChangeMask
        FOCUS_IN = 9          # X.FocusIn
        FOCUS_OUT = 10        # X.FocusOut

        while True:
            try:
                event = self.d.next_event()

                # Check if window list update is needed
                should_update = False

                # Compare using event type values
                if event.type == PROPERTY_CHANGE:
                    # Window property changed, check if it's window state or title change
                    atom_name = self.d.get_atom_name(event.atom)
                    if atom_name in ["_NET_WM_NAME", "WM_NAME", "_NET_WM_STATE",
                                    "_NET_ACTIVE_WINDOW", "_NET_CLIENT_LIST"]:
                        should_update = True
                elif event.type == FOCUS_IN or event.type == FOCUS_OUT:
                    # Focus changed
                    should_update = True

                if should_update:
                    # Add delay to prevent continuous triggering
                    time.sleep(0.1)
                    self.update_window_list()

            except Exception as e:
                print(f"Event loop error: {e}")
                time.sleep(0.1)  # Delay on error

    def polling_loop(self):
        """Polling loop (fallback)"""
        while True:
            try:
                self.update_window_list()
                time.sleep(2)  # Poll every 2 seconds
            except Exception as e:
                print(f"Polling loop error: {e}")
                time.sleep(2)

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = WindowSwitcher()
    app.run()
