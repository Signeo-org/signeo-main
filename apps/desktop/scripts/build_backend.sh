#!/usr/bin/env bash
set -e  # exit if any command fails

# set working directory to the script's location
cd "$(dirname "$0")"

cd ../backend

# Check if both binary and model files exist
if ls build/Release/AudioTranscriptionTool* 1> /dev/null 2>&1 \
   && compgen -G "build/Release/models/*.bin" > /dev/null; then
    echo "✅ Required files found, skipping rebuild."
else
    echo "❌ Missing binary or model files. Cleaning build/ and rebuilding..."
    rm -rf build

    # Build the backend
    ./scripts/build.sh
fi

cd ..

# Copy the backend build to the frontend resources
mkdir -p frontend/resources
cp backend/build/Release/AudioTranscriptionTool* frontend/resources/

mkdir -p frontend/resources/models
cp backend/build/Release/models/*.bin frontend/resources/models/
