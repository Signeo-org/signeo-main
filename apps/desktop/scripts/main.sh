#!/usr/bin/env bash
set -e  # exit on first error

# set working directory to the script's location
cd "$(dirname "$0")"

# use the build script from the backend
./build_backend.sh

# use the start script from the frontend
cd ../frontend
./scripts/start.sh

# return to the root project folder (optional)
cd ..
