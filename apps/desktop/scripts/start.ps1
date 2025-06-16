$frontendPath = Join-Path $PSScriptRoot '..' 'frontend'
$backendPath = Join-Path $PSScriptRoot '..' 'backend'

Start-Process powershell -ArgumentList '-NoExit', '-Command', "Set-Location -LiteralPath '$frontendPath'; ./scripts/start_dev.ps1"
Start-Process powershell -ArgumentList '-NoExit', '-Command', "Set-Location -LiteralPath '$backendPath'; ./scripts/run.ps1"

