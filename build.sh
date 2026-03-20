#!/bin/bash
set -e

echo "Checking for Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    echo "Command Line Tools not found. Initiating installation..."
    xcode-select --install
    echo "Please wait for the Apple Command Line Tools installation dialog to complete, then run this script again."
    exit 1
fi

echo "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Please install Homebrew first from https://brew.sh/ to proceed."
    exit 1
fi

echo "Checking for QuickJS..."
if ! brew list quickjs &> /dev/null; then
    echo "QuickJS not found. Installing via Homebrew..."
    brew install quickjs
fi

echo "All prerequisites met. Starting build process..."


echo "Building Metal Shaders..."
xcrun -sdk macosx metal -c shaders/Shaders.metal -o shaders/Shaders.air
xcrun -sdk macosx metallib shaders/Shaders.air -o RedCube.app/Contents/Resources/default.metallib

echo "Building QuickJS Bridge..."
cc -c quickjs/QuickJSBridge.c -I/opt/homebrew/include -o quickjs/QuickJSBridge.o

echo "Building Swift Application..."
swiftc -o RedCube.app/Contents/MacOS/RedCube \
    app/App.swift \
    app/MetalView.swift \
    app/Renderer.swift \
    app/Math.swift \
    quickjs/QuickJSBridge.o \
    -import-objc-header app/Bridging-Header.h \
    -L/opt/homebrew/lib/quickjs -lquickjs \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -framework Metal -framework MetalKit -framework SwiftUI -framework AppKit -framework QuartzCore

echo "Copying assets..."
cp scripts/scene.js RedCube.app/Contents/Resources/

echo "Build complete. Launching RedCube.app..."
pkill -9 RedCube || true
open RedCube.app
