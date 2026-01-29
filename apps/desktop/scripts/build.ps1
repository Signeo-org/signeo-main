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

# Path resolution
$ScriptRoot = $PSScriptRoot
$DesktopRoot = Resolve-Path "$ScriptRoot\.."
$BackendRoot = Join-Path $DesktopRoot "backend"
$FrontendRoot = Join-Path $DesktopRoot "frontend"

# Build backend
if (-not ($Dev -or $Prod -or $Test -or $Coverage)) { $Dev = $true }

# =============================================================================
# Dev Mode
# =============================================================================
if ($Dev) {
    Write-Host "`n🚀 Signeo Desktop - Development`n" -ForegroundColor Cyan
    
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
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }
    
    # Start frontend (reads from backend/build directly)
    Write-Host "[2/2] Starting frontend..." -ForegroundColor Yellow
    Push-Location $FrontendRoot
    try {
        if (-not (Test-Path "node_modules")) { pnpm install }
        pnpm dev
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Prod Mode
# =============================================================================
elseif ($Prod) {
    Write-Host "`n📦 Signeo Desktop - Production`n" -ForegroundColor Magenta
    
    $ReleaseDir = "$DesktopRoot\release"
    
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
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }
    
    # Bundle backend to frontend/resources (Handled by package.json extraResources)
    Write-Host "[2/5] Bundling backend (Handled by electron-builder)..." -ForegroundColor Yellow
    
    # Verify backend exists
    if (-not (Test-Path "$FrontendRoot\..\backend\dist")) {
        Write-Error "Missing backend dist folder. Build backend first."
        exit 1
    }
    
    Write-Host "  ✓ Backend dist found" -ForegroundColor Green
    
    # Build frontend
    Write-Host "[4/5] Building frontend..." -ForegroundColor Yellow
    Push-Location $FrontendRoot
    try {
        pnpm install --frozen-lockfile
        pnpm build
    }
    finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # Collect release
    Write-Host "[5/5] Collecting release..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
    
    # Copy portable exe and unpacked folder
    if (Test-Path "$FrontendRoot\dist\release\*.exe") {
        Copy-Item "$FrontendRoot\dist\release\*.exe" $ReleaseDir -Force
    }
    if (Test-Path "$FrontendRoot\dist\release\win-unpacked") {
        Copy-Item "$FrontendRoot\dist\release\win-unpacked" "$ReleaseDir\Signeo-portable" -Recurse -Force
    }
    
    Write-Host "`n✅ Release: $ReleaseDir" -ForegroundColor Green
    Get-ChildItem $ReleaseDir -ErrorAction SilentlyContinue | ForEach-Object {
        $size = if ($_.PSIsContainer) { 
            (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB 
        }
        else { 
            $_.Length / 1MB 
        }
        Write-Host "   $($_.Name) ($([math]::Round($size, 1)) MB)" -ForegroundColor White
    }
}

# =============================================================================
# Test/Coverage
# =============================================================================
elseif ($Test) {
    Write-Host "`n🧪 Tests`n" -ForegroundColor Blue
    & "$BackendRoot\scripts\test_docker.ps1"
}
elseif ($Coverage) {
    Write-Host "`n📊 Coverage`n" -ForegroundColor Green
    & "$BackendRoot\scripts\gen_coverage.ps1"
}
