#!/usr/bin/env bash
set -e  # exit if any command fails

# set working directory to the script's location
cd "$(dirname "$0")"

# Build the backend
cd ../backend
./scripts/build.sh
cd ..

# Copy the backend build to the frontend resources
mkdir -p frontend/resources

# Copy the built binary (works on Windows, macOS, Linux)
if ls backend/build/Release/AudioTranscriptionTool* 1> /dev/null 2>&1; then
    cp backend/build/Release/AudioTranscriptionTool* frontend/resources/
fi

# Copy .bin model files if they exist
if compgen -G "backend/build/Release/models/*.bin" > /dev/null; then
    mkdir -p frontend/resources/models
    cp backend/build/Release/models/*.bin frontend/resources/models/
fi
