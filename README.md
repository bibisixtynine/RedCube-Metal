# metalJS: Metal + JavaScript Renderer

## Project Overview
metalJS is an interactive macOS application that combines the high-performance 3D rendering capabilities of Apple's **Metal** framework with the lightweight scripting power of the **QuickJS** engine. It allows users to write JavaScript code in a built-in text editor to programmatically generate and control 3D scenes (specifically, rotating colored cubes) in real time.

## Goal
The primary goal of this project is to demonstrate how to bridge a fast, compiled graphics API (Metal) with a dynamic scripting language (JavaScript). This provides a flexible playground where developers or artists can instantly see the results of their code without needing to recompile the entire Swift application, creating an ideal environment for rapid prototyping, creative coding, and educational purposes.

## Architecture & Design
The application is structured into three main layers:

1. **User Interface (SwiftUI):** A modern macOS layout containing a live Metal canvas and a live JavaScript text editor. Features centered icon-based controls (SF Symbols) and an external resizable Help window.
2. **Graphics Engine (Metal & MetalKit):** A custom `Renderer` class handles the graphics pipeline, 24-vertex cube geometry (for flat shading), and directional lighting. Supports instanced drawing of up to 10,000 cubes.
3. **Scripting Engine (QuickJS):** A C-based bridge (`QuickJSBridge.c/.h`) embeds the QuickJS runtime. It exposes native functions like `drawCube` (with hex color support) and handles high-frequency frame callbacks.

## Libraries and Frameworks Used
- **SwiftUI:** For building the modern, reactive macOS user interface.
- **Metal / MetalKit:** Apple's low-level, hardware-accelerated graphics API for rendering 3D graphics.
- **QuickJS:** A small and embeddable JavaScript engine, used to parse and execute user-provided scripts safely and quickly.
- **simd:** Used for high-performance vectorized math operations, specifically for 3D matrix transformations (translation, rotation, and projection).

## What You Can Do With It
You can interactively populate the 3D scene by writing JavaScript in the editor. 

**Exposed API:**
- `drawCube(x, y, z, size, color?)`: Renders a cube at `(x, y, z)` with a given `size`. The `color` parameter is an optional hex string in `#aarrggbb` format (e.g., `"#80ff0000"` for semi-transparent red).
- `clearCubes()`: Clears the scene (required for animation).
- `setCamera(px, py, pz, tx, ty, tz)`: Positions the camera and its target.
- `requestAnimationFrame(callback)`: Standard JS animation loop at 60fps.

**Example Usage:**
You can write loops, algorithms, or generative scripts to create complex structures:

```javascript
// Position the camera
setCamera(3, 3, 3, 0, 0, 0);

// A simple 3D grid of colored cubes
for (let x = -1; x <= 1; x = x + 0.5) {
    for (let y = -1; y <= 1; y = y + 0.5) {
        // Red to yellow gradient based on position
        const green = Math.floor((y + 1) / 2 * 255).toString(16).padStart(2, '0');
        const color = "#ffff" + green + "00"; 
        drawCube(x, y, 0, 0.1, color);
    }
}
```

## Features
- **Dynamic Lighting**: Real-time directional lighting (Lambertian) ensures that 3D shapes are clearly defined, even for solid-colored objects.
- **External Help Window**: A dedicated, movable, and resizable macOS panel containing documentation and interactive examples that can be inserted directly at your cursor.
- **Modernized UI**: Sleek, centered toolbar using SF Symbols for common actions (Load, Save, Play, Pause, Help).
- **Trackpad Interaction**: Built-in support for scroll, zoom (pinch), and drag through the `_onEvent` hook.
- **High Performance**: Native Metal instancing allows for thousands of cubes at 60 FPS.
- **Project Gallery**: Includes advanced examples like `cassecube.js` (a full 3D breakout game).
- **Load & Save Scripts**: Native macOS dialogs accessible via icons in the toolbar.

## Technical Limits
The renderer currently supports up to **10,000 cubes** simultaneously. 
- **Why 10,000?** This limit ensures that the application remains extremely smooth (60+ FPS) since the math for every cube is currently calculated on the CPU before being sent to the Metal GPU.
- **Instanced Rendering:** The engine uses advanced instanced rendering, meaning it draws all 10,000 cubes in a single high-performance operation rather than drawing them one by one.

## Running the App
A pre-compiled version of the application (`metalJS.app`) is included directly within the repository. You can simply clone this repository and double-click `metalJS.app` in Finder to launch the application immediately.

## Building from Source
This application was created without Xcode using the **Antigravity AI Assistant**. The entire application is built using terminal tools via Apple's Command Line Tools and the open-source QuickJS engine.

### Prerequisites (macOS)
To compile the app yourself without a full Xcode installation, you only need the macOS Command Line Tools. The QuickJS engine source code is already included in this repository.
1. Install Command Line Tools: `xcode-select --install`
   *(Note: This prompts a small download for the necessary compilers like `swiftc` and `metal`. It **does not** require installing the massive Xcode app.)*

### Compilation
The project includes a `build.sh` script to automate compilation. Run the following command from the project root:
```bash
./build.sh
```
This script will compile the Metal shaders (`xcrun metal`), the QuickJS C bridge (`cc`), the Swift application (`swiftc`), and bundle everything into `metalJS.app`.
