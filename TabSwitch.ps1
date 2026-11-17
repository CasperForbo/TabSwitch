Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class TabSwitchWindow {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr handle, int command);
}
'@

$script:configPath = Join-Path $PSScriptRoot 'config.json'
$script:config = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
$script:intervalMinutes = 5.0
if ($null -ne $script:config.IntervalMinutes) {
    $script:intervalMinutes = [double]$script:config.IntervalMinutes
}
if ($script:intervalMinutes -le 0) {
    throw 'IntervalMinutes must be greater than zero.'
}

$script:browserNames = @('msedge', 'chrome', 'firefox', 'brave', 'opera', 'vivaldi')
if ($null -ne $script:config.BrowserProcessNames) {
    $script:browserNames = @($script:config.BrowserProcessNames)
}
$script:nextTab = 1

function Invoke-TabSwitch {
    foreach ($browserName in $script:browserNames) {
        $browser = Get-Process -Name $browserName -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
        if ($null -eq $browser) {
            continue
        }

        [void][TabSwitchWindow]::ShowWindow($browser.MainWindowHandle, 9)
        if ([TabSwitchWindow]::SetForegroundWindow($browser.MainWindowHandle)) {
            Start-Sleep -Milliseconds 150
            [System.Windows.Forms.SendKeys]::SendWait("^$script:nextTab")
            $script:nextTab = if ($script:nextTab -eq 1) { 2 } else { 1 }
        }
        return
    }
}

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

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = [Math]::Max(1000, [int]($script:intervalMinutes * 60000))
$script:timer.add_Tick({ Invoke-TabSwitch })

Invoke-TabSwitch
$script:timer.Start()
[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))