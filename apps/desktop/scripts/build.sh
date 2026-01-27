#!/usr/bin/env bash
# Signeo Desktop - Unified Build Script
# Usage: ./build.sh [-dev|-prod|-test|-coverage] [--gpu] [--clean] [--skip-backend]

set -e

MODE="dev"; GPU=false; CLEAN=false; SKIP_BACKEND=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -dev|--dev) MODE="dev"; shift ;;
        -prod|--prod) MODE="prod"; shift ;;
        -test|--test) MODE="test"; shift ;;
        -coverage|--coverage) MODE="coverage"; shift ;;
        --gpu|-gpu) GPU=true; shift ;;
        --clean|-clean) CLEAN=true; shift ;;
        --skip-backend) SKIP_BACKEND=true; shift ;;
        *) shift ;;
    esac
done

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_ROOT="$DESKTOP_ROOT/backend"
FRONTEND_ROOT="$DESKTOP_ROOT/frontend"

# Dev Mode
if [ "$MODE" = "dev" ]; then
    echo -e "\n🚀 Signeo Desktop - Development\n"
    
    # Build backend (CMake handles all file copying)
    if [ "$SKIP_BACKEND" = false ]; then
        echo "[1/2] Building backend..."
        ARGS="-dev"; [ "$GPU" = true ] && ARGS="$ARGS --gpu"; [ "$CLEAN" = true ] && ARGS="$ARGS --clean"
        bash "$BACKEND_ROOT/scripts/build.sh" $ARGS
    fi
    
    # Start frontend (reads from backend/build directly)
    echo "[2/2] Starting frontend..."
    cd "$FRONTEND_ROOT"
    [ ! -d "node_modules" ] && pnpm install
    pnpm dev

# Prod Mode
elif [ "$MODE" = "prod" ]; then
    echo -e "\n📦 Signeo Desktop - Production\n"
    
    RELEASE_DIR="$DESKTOP_ROOT/release"
    RESOURCES_DIR="$FRONTEND_ROOT/resources"
    BUILD_DIR="$BACKEND_ROOT/build"; [ "$GPU" = true ] && BUILD_DIR="$BACKEND_ROOT/build_gpu"
    
    # Build backend
    if [ "$SKIP_BACKEND" = false ]; then
        echo "[1/4] Building backend (Release)..."
        ARGS="-prod"; [ "$GPU" = true ] && ARGS="$ARGS --gpu"; [ "$CLEAN" = true ] && ARGS="$ARGS --clean"
        bash "$BACKEND_ROOT/scripts/build.sh" $ARGS
    fi
    
    # Bundle for electron-builder
    echo "[2/4] Bundling backend for packaging..."
    mkdir -p "$RESOURCES_DIR"
    cp "$BUILD_DIR/signeo-core" "$RESOURCES_DIR/" 2>/dev/null || true
    cp "$BUILD_DIR"/*.so* "$RESOURCES_DIR/" 2>/dev/null || true
    [ -d "$BUILD_DIR/models" ] && cp -r "$BUILD_DIR/models" "$RESOURCES_DIR/"
    echo "  ✓ Backend bundled to resources/"
    
    # Build frontend
    echo "[3/4] Building frontend..."
    cd "$FRONTEND_ROOT"; pnpm install; pnpm build
    
    # Collect release
    echo "[4/4] Collecting release..."
    mkdir -p "$RELEASE_DIR"
    cp -r "$FRONTEND_ROOT/dist/release"/* "$RELEASE_DIR/" 2>/dev/null || true
    
    echo -e "\n✅ Release: $RELEASE_DIR"

# Test/Coverage
elif [ "$MODE" = "test" ]; then
    echo -e "\n🧪 Tests\n"
    bash "$BACKEND_ROOT/scripts/test_docker.sh"
elif [ "$MODE" = "coverage" ]; then
    echo -e "\n📊 Coverage\n"
    bash "$BACKEND_ROOT/scripts/gen_coverage.sh"
fi
