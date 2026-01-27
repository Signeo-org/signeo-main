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

# Default to Dev
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
    $ResourcesDir = "$FrontendRoot\backend"
    $BuildDir = "$BackendRoot\build"
    
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
    
    # Bundle backend to frontend/resources
    Write-Host "[2/5] Bundling backend for packaging..." -ForegroundColor Yellow
    
    # Clean resources (remove old binaries, keep .gitignore)
    if (Test-Path $ResourcesDir) {
        Get-ChildItem $ResourcesDir -Exclude ".gitignore", "SL" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $ResourcesDir -Force | Out-Null
    
    # Copy executable
    if (Test-Path "$BuildDir\signeo-core.exe") {
        Copy-Item "$BuildDir\signeo-core.exe" $ResourcesDir -Force
        Write-Host "  ✓ signeo-core.exe" -ForegroundColor Green
    }
    else {
        Write-Error "Missing: signeo-core.exe"
        exit 1
    }
    
    # Copy ONNX Runtime DLLs
    Copy-Item "$BuildDir\onnxruntime.dll" $ResourcesDir -Force
    Write-Host "  ✓ onnxruntime.dll" -ForegroundColor Green
    
    if ($Gpu) {
        if (Test-Path "$BuildDir\onnxruntime_providers_cuda.dll") {
            Copy-Item "$BuildDir\onnxruntime_providers_cuda.dll" $ResourcesDir -Force
            Copy-Item "$BuildDir\onnxruntime_providers_shared.dll" $ResourcesDir -Force
            Write-Host "  ✓ CUDA provider DLLs" -ForegroundColor Green
        }
    }
    
    # Copy models (excluding large turbo model)
    if (Test-Path "$BuildDir\models") {
        New-Item -ItemType Directory -Path "$ResourcesDir\models" -Force | Out-Null
        Get-ChildItem "$BuildDir\models" -Exclude "ggml-large-v3-turbo*", "ggml-base*" | ForEach-Object {
            Copy-Item $_.FullName "$ResourcesDir\models\" -Force
            Write-Host "  ✓ models\$($_.Name)" -ForegroundColor Green
        }
    }
    
    # Copy config files
    if (Test-Path "$BuildDir\config.ini") {
        Copy-Item "$BuildDir\config.ini" $ResourcesDir -Force
        Write-Host "  ✓ config.ini" -ForegroundColor Green
    }
    if (Test-Path "$BuildDir\example.env") {
        Copy-Item "$BuildDir\example.env" $ResourcesDir -Force
        Write-Host "  ✓ example.env" -ForegroundColor Green
    }
    
    # Calculate bundle size
    $BundleSize = (Get-ChildItem $ResourcesDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  Total: $([math]::Round($BundleSize, 1)) MB" -ForegroundColor Cyan
    
    # Verify required files
    Write-Host "[3/5] Verifying bundle..." -ForegroundColor Yellow
    $RequiredFiles = @("signeo-core.exe", "onnxruntime.dll", "models\silero_vad.onnx", "models\ggml-small.en.bin")
    $Missing = @()
    foreach ($file in $RequiredFiles) {
        if (-not (Test-Path "$ResourcesDir\$file")) {
            $Missing += $file
        }
    }
    if ($Missing.Count -gt 0) {
        Write-Error "Missing required files: $($Missing -join ', ')"
        exit 1
    }
    Write-Host "  ✓ All required files present" -ForegroundColor Green
    
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
