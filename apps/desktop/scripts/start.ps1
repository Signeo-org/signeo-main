# Function to check if running as Administrator
function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$needsAdmin = $false

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found."
    $needsAdmin = $true
}

# Check if Yarn is installed
if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) {
    Write-Host "Yarn not found."
    $needsAdmin = $true
}

# If admin rights are needed but not present, abort
if ($needsAdmin -and -not (Test-IsAdmin)) {
    Write-Warning "Chocolatey or Yarn needs to be installed, but this script is not running with administrator privileges."
    Write-Warning "Please re-run this PowerShell script as an administrator."
    exit 1
}

# Install Chocolatey if needed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install Yarn if needed
if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Yarn via Chocolatey..."
    choco install yarn -y
}

# Start the frontend and backend scripts
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd ../frontend; ./scripts/start_dev.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd ../backend; ./scripts/run.ps1"
