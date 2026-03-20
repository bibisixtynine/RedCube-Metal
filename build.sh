#!/bin/bash
set -e

echo "Checking for Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    echo "Command Line Tools not found. Initiating installation..."
    xcode-select --install
    echo "Please wait for the Apple Command Line Tools installation dialog to complete, then run this script again."
    exit 1
fi

echo "Preparing app bundle..."
mkdir -p metalJS.app/Contents/MacOS metalJS.app/Contents/Resources
cp app/Info.plist metalJS.app/Contents/Info.plist
cp app/AppIcon.icns metalJS.app/Contents/Resources/AppIcon.icns

echo "Building QuickJS Engine (Vendored)..."
make -C vendor/quickjs libquickjs.a

echo "Building QuickJS Bridge..."
cc -c quickjs/QuickJSBridge.c -Ivendor/quickjs -o quickjs/QuickJSBridge.o

echo "Building Swift Application..."
swiftc -o metalJS.app/Contents/MacOS/metalJS \
    app/App.swift app/RealityRenderer.swift app/APIServer.swift \
    quickjs/QuickJSBridge.o \
    -import-objc-header app/Bridging-Header.h \
    -Lvendor/quickjs -lquickjs \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -framework RealityKit -framework SwiftUI -framework AppKit -framework QuartzCore -framework Combine -framework Network

echo "Copying assets..."
rm -rf metalJS.app/Contents/Resources/*
cp js-examples/*.js metalJS.app/Contents/Resources/

echo "Build complete. Launching metalJS.app..."
pkill -9 metalJS || true
open metalJS.app
