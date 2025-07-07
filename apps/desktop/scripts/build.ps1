
# Build the backend
Set-Location -Path "./backend"
./scripts/build.ps1

# Copy the backend build to the frontend resources
Set-Location -Path "../"
if (Test-Path "backend/build/Release/*.exe") {
    New-Item -ItemType Directory -Path "frontend/resources" -Force | Out-Null
    Copy-Item -Path "backend/build/Release/*.exe" -Destination "frontend/resources/" -Recurse -Force
}

if (Test-Path "backend/build/Release/models/*.bin") {
    New-Item -ItemType Directory -Path "frontend/resources/models" -Force | Out-Null
    Copy-Item -Path "backend/build/Release/models/*.bin" -Destination "frontend/resources/models/" -Recurse -Force
}

# Build the frontend
Set-Location -Path "./frontend"
./scripts/build.ps1
Set-Location -Path "../"
