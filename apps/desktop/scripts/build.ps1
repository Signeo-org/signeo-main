
# Use the build script from the backend
Set-Location -Path "./backend"
./scripts/build.ps1

# Copy the backend build to the frontend
Set-Location -Path "../"
Copy-Item -Path "backend/build/Release/*.exe" -Destination "frontend/resources" -Recurse -Force
Copy-Item -Path "backend/build/Release/models/*.bin" -Destination "frontend/resources/models" -Recurse -Force

# Use the build script from the frontend
Set-Location -Path "./frontend"
./scripts/build.ps1
Set-Location -Path "../"
