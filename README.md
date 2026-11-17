# TabSwitch

TabSwitch is a small Windows tray utility that alternates between browser tabs 1 and 2. It tries to switch as soon as it starts, then repeats on the configured interval.

## Run

Double-click `TabSwitch.bat` to launch TabSwitch without leaving a PowerShell window open. You can also run `TabSwitch.ps1` directly with Windows PowerShell. To start it automatically when you sign in, double-click `install-startup.bat`. It creates a shortcut in your current user's Startup folder and launches TabSwitch. Set `StartWithWindows` to `false` in `config.json` and run the installer again to remove that shortcut. To remove the startup shortcut directly, double-click `uninstall-startup.bat`; this does not change the configuration or close an already-running TabSwitch instance.

TabSwitch runs in the notification area. Right-click its icon to switch immediately, open the configuration, or exit. If no configured browser window is available, a switch is skipped and the same tab is retried at the next interval.

## Configuration

Edit `config.json` beside `TabSwitch.ps1`:

- `IntervalMinutes`: minutes between switches; must be a positive number.
- `StartWithWindows`: whether the startup installer registers the app.
- `BrowserProcessNames`: browser process names, without `.exe`, checked in order.

After changing `StartWithWindows`, rerun the installer to apply the startup setting. Other changes apply the next time TabSwitch is launched.