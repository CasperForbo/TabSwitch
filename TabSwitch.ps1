# Required assemblies for the tray icon and Windows input APIs.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Win32 interop used to restore and focus browser windows, then send Ctrl+1 / Ctrl+2.
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class TabSwitchWindow {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr handle, int command);
}
'@

# Load configuration options from the sibling config.json file.
$script:configPath = Join-Path $PSScriptRoot 'config.json'
$script:config = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json

# Default polling interval is five minutes, unless configuration overrides it.
$script:intervalMinutes = 5.0
if ($null -ne $script:config.IntervalMinutes) {
    $script:intervalMinutes = [double]$script:config.IntervalMinutes
}
if ($script:intervalMinutes -le 0) {
    throw 'IntervalMinutes must be greater than zero.'
}

# Browser process names to cycle through. These can be overridden via config.
$script:browserNames = @('msedge', 'chrome', 'firefox', 'brave', 'opera', 'vivaldi')
if ($null -ne $script:config.BrowserProcessNames) {
    $script:browserNames = @($script:config.BrowserProcessNames)
}

# Alternate between tab 1 and tab 2 for each browser window.
$script:nextTab = 1

# Switches focus to the first visible browser window, restores it if minimized,
# and sends Ctrl+1 or Ctrl+2 to cycle through tabs.
function Invoke-TabSwitch {
    foreach ($browserName in $script:browserNames) {
        $browser = Get-Process -Name $browserName -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
        if ($null -eq $browser) {
            continue
        }

        if ([TabSwitchWindow]::IsIconic($browser.MainWindowHandle)) {
            [void][TabSwitchWindow]::ShowWindow($browser.MainWindowHandle, 9)
        }
        if ([TabSwitchWindow]::SetForegroundWindow($browser.MainWindowHandle)) {
            Start-Sleep -Milliseconds 150
            [System.Windows.Forms.SendKeys]::SendWait("^$script:nextTab")
            $script:nextTab = if ($script:nextTab -eq 1) { 2 } else { 1 }
        }
        return
    }
}

# Create the tray icon and context menu so the user can trigger a switch or exit quickly.
$script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
$script:trayIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:trayIcon.Text = "TabSwitch: every $($script:intervalMinutes) minutes"
$script:trayIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$switchNowItem = $menu.Items.Add('Switch now')
$switchNowItem.add_Click({ Invoke-TabSwitch })
$configItem = $menu.Items.Add('Open config')
$configItem.add_Click({ Start-Process notepad.exe -ArgumentList "`"$script:configPath`"" })
$menu.Items.Add('-') | Out-Null
$exitItem = $menu.Items.Add('Exit')
$exitItem.add_Click({
    $script:timer.Stop()
    $script:trayIcon.Visible = $false
    $script:trayIcon.Dispose()
    [System.Windows.Forms.Application]::ExitThread()
})
$script:trayIcon.ContextMenuStrip = $menu

# Timer-based automation: run the tab switch routine at the configured interval.
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = [Math]::Max(1000, [int]($script:intervalMinutes * 60000))
$script:timer.add_Tick({ Invoke-TabSwitch })

# Perform an immediate switch when the app starts, then keep the tray app alive.
Invoke-TabSwitch
$script:timer.Start()
[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))