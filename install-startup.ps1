$configPath = Join-Path $PSScriptRoot 'config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$startupPath = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupPath 'TabSwitch.lnk'

if ($config.StartWithWindows -eq $false) {
    Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction SilentlyContinue
    Write-Output 'Startup shortcut removed because StartWithWindows is false.'
} else {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'TabSwitch.ps1')`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = 'Switch between the first two browser tabs on a timer.'
    $shortcut.Save()
    Start-Process -FilePath $shortcut.TargetPath -ArgumentList $shortcut.Arguments
    Write-Output "Startup shortcut created at $shortcutPath and TabSwitch started."
}