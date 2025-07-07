
#use the build script from the backend
./scripts/build.ps1

#use the deploy script from the frontend
Set-Location -Path "./frontend"
./scripts/deploy.ps1
Set-Location -Path "../"

#Copy the deploy exe file to this location
Copy-Item -Path "frontend/dist/release/*.exe" -Destination "./" -Recurse -Force
