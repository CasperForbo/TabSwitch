# Required assemblies for the tray icon and Windows input APIs.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Win32 interop used to restore and focus browser windows before sending Ctrl+Tab.
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

# Optional startup windows for Microsoft Edge. Each item is one window and each
# inner item is a URL to open in that window. Example:
# "EdgeStartupWindows": [["https://site1.example","https://site2.example"],["https://site3.example"]]
$script:edgeStartupWindows = @()
if ($null -ne $script:config.EdgeStartupWindows) {
    $script:edgeStartupWindows = @($script:config.EdgeStartupWindows)
}

# Starts the configured Edge windows, whether or not Edge is already running.
function Open-EdgeStartupWindows {
    if ($script:edgeStartupWindows.Count -eq 0) {
        return
    }

    $edgePath = $null
    $edgeCommand = Get-Command -Name 'msedge' -ErrorAction SilentlyContinue
    if ($null -ne $edgeCommand) {
        $edgePath = $edgeCommand.Source
    }
    else {
        $candidatePaths = @(
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
        )
        foreach ($candidatePath in $candidatePaths) {
            if (Test-Path -LiteralPath $candidatePath) {
                $edgePath = $candidatePath
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($edgePath)) {
        return
    }

    foreach ($windowUrls in $script:edgeStartupWindows) {
        $urls = @($windowUrls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($urls.Count -eq 0) {
            continue
        }

        $arguments = @('--new-window') + $urls
        Start-Process -FilePath $edgePath -ArgumentList $arguments
    }
}

# Send F11 once after the first successful tab switch.
$script:sendFullscreenShortcutAfterFirstSwitch = $true

# Switches focus to the first visible browser window, restores it if minimized,
# and sends Ctrl+Tab to cycle through tabs.
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
            [System.Windows.Forms.SendKeys]::SendWait('^{TAB}')
            if ($script:sendFullscreenShortcutAfterFirstSwitch) {
                [System.Windows.Forms.SendKeys]::SendWait('{F11}')
                $script:sendFullscreenShortcutAfterFirstSwitch = $false
            }
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

# Open any configured Edge startup windows before the tab-switch timer begins.
Open-EdgeStartupWindows

# Perform an immediate switch when the app starts, then keep the tray app alive.
Invoke-TabSwitch
$script:timer.Start()
[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))