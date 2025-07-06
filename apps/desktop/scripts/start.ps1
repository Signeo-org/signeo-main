
#use the build script from the backend
./scripts/build.ps1

#use the start script from the frontend
Set-Location -Path "./frontend"
./scripts/start.ps1
Set-Location -Path "../"
