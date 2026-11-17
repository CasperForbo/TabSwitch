$startupPath = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupPath 'TabSwitch.lnk'
Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction SilentlyContinue
Write-Output 'TabSwitch startup shortcut removed.'