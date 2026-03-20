#!/bin/bash
set -e

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
