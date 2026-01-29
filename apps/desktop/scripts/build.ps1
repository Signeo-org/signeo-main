<#
.SYNOPSIS
    Unified build script for Signeo Desktop.

.PARAMETER Dev
    Development: build backend + start frontend dev server.

.PARAMETER Prod
    Production: release build + package.

.PARAMETER Test
    Run tests.

.PARAMETER Coverage
    Generate coverage.

.PARAMETER Gpu
    GPU (CUDA) support.

.PARAMETER Clean
    Clean rebuild.

.PARAMETER SkipBackend
    Skip backend build.

.PARAMETER Compiler
    Compiler selection: Auto, MSVC, Clang.

.EXAMPLE
    .\build.ps1 -Dev          # Development
    .\build.ps1 -Prod         # Production portable
    .\build.ps1 -Prod -Gpu    # Production with GPU support
    .\build.ps1 -Test         # Tests
#>

param (
    [switch]$Dev,
    [switch]$Prod,
    [switch]$Test,
    [switch]$Coverage,
    [switch]$Gpu,
    [switch]$Clean,
    [switch]$SkipBackend,
    [ValidateSet("Auto", "MSVC", "Clang")]
    [string]$Compiler = "Auto"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# -----------------------------------------------------------------------------
# Path resolution
# -----------------------------------------------------------------------------
$ScriptRoot   = $PSScriptRoot
$DesktopRoot  = Resolve-Path (Join-Path $ScriptRoot "..")
$BackendRoot  = Join-Path $DesktopRoot "backend"
$FrontendRoot = Join-Path $DesktopRoot "frontend"

# Default mode
if (-not ($Dev -or $Prod -or $Test -or $Coverage)) { $Dev = $true }

# Helper: run a command and fail fast if exit code != 0
function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Command,
        [string]$ErrorMessage = "Command failed."
    )
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error $ErrorMessage
        exit $LASTEXITCODE
    }
}

# =============================================================================
# Dev Mode
# =============================================================================
if ($Dev) {
    Write-Host "`nSigneo Desktop - Development`n" -ForegroundColor Cyan

    # Build backend
    if (-not $SkipBackend) {
        Write-Host "[1/2] Building backend..." -ForegroundColor Yellow

        $buildArgs = @{
            Dev      = $true
            Compiler = $Compiler
            Gpu      = $Gpu
            Clean    = $Clean
        }

        & "$BackendRoot\scripts\build.ps1" @buildArgs
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    # Start frontend (reads from backend/build directly)
    Write-Host "[2/2] Starting frontend..." -ForegroundColor Yellow
    Push-Location $FrontendRoot
    try {
        if (-not (Test-Path "node_modules")) {
            Invoke-Checked { pnpm install } "pnpm install failed."
        }
        Invoke-Checked { pnpm dev } "pnpm dev failed."
    }
    finally {
        Pop-Location
    }

    exit 0
}

# =============================================================================
# Prod Mode
# =============================================================================
elseif ($Prod) {
    Write-Host "`nSigneo Desktop - Production`n" -ForegroundColor Magenta

    $ReleaseDir = Join-Path $DesktopRoot "release"

    # Build backend
    if (-not $SkipBackend) {
        Write-Host "[1/5] Building backend (Release)..." -ForegroundColor Yellow

        $buildArgs = @{
            Prod     = $true
            Compiler = $Compiler
            Gpu      = $Gpu
            Clean    = $Clean
        }

        & "$BackendRoot\scripts\build.ps1" @buildArgs
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    # Bundle backend to frontend/resources (Handled by package.json extraResources)
    Write-Host "[2/5] Bundling backend (Handled by electron-builder)..." -ForegroundColor Yellow

    # Verify backend exists
    $BackendDist = Join-Path $DesktopRoot "backend\dist"
    if (-not (Test-Path $BackendDist)) {
        Write-Error "Missing backend dist folder ($BackendDist). Build backend first."
        exit 1
    }
    Write-Host "  OK: Backend dist found" -ForegroundColor Green

    # Build frontend
    Write-Host "[3/5] Installing frontend deps..." -ForegroundColor Yellow
    Push-Location $FrontendRoot
    try {
        Invoke-Checked { pnpm install --frozen-lockfile } "pnpm install --frozen-lockfile failed."
        Write-Host "[4/5] Building frontend..." -ForegroundColor Yellow
        Invoke-Checked { pnpm build } "pnpm build failed."
    }
    finally {
        Pop-Location
    }

    # Collect release
    Write-Host "[5/5] Collecting release..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    # Copy portable exe and unpacked folder
    $ExeGlob = Join-Path $FrontendRoot "dist\release\*.exe"
    if (Test-Path $ExeGlob) {
        Copy-Item $ExeGlob $ReleaseDir -Force
    }

    $UnpackedDir = Join-Path $FrontendRoot "dist\release\win-unpacked"
    if (Test-Path $UnpackedDir) {
        Copy-Item $UnpackedDir (Join-Path $ReleaseDir "Signeo-portable") -Recurse -Force
    }

    Write-Host "`nRelease: $ReleaseDir" -ForegroundColor Green

    Get-ChildItem $ReleaseDir -ErrorAction SilentlyContinue | ForEach-Object {
        $sizeMB = if ($_.PSIsContainer) {
            $sum = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sum) { 0 } else { $sum / 1MB }
        }
        else {
            $_.Length / 1MB
        }

        Write-Host ("   {0} ({1} MB)" -f $_.Name, ([math]::Round($sizeMB, 1))) -ForegroundColor White
    }

    exit 0
}

# =============================================================================
# Test/Coverage
# =============================================================================
elseif ($Test) {
    Write-Host "`nTests`n" -ForegroundColor Blue
    & "$BackendRoot\scripts\test_docker.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    exit 0
}
elseif ($Coverage) {
    Write-Host "`nCoverage`n" -ForegroundColor Green
    & "$BackendRoot\scripts\gen_coverage.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    exit 0
}

exit 0
