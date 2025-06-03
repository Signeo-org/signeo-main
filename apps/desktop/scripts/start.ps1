Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd ../frontend; ./scripts/start_dev.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd ../backend; ./scripts/run.ps1"
