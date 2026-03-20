# metalJS: Metal + JavaScript Renderer

## Project Overview
metalJS is an interactive macOS application that combines the high-performance 3D rendering capabilities of Apple's **Metal** framework with the lightweight scripting power of the **QuickJS** engine. It allows users to write JavaScript code in a built-in text editor to programmatically generate and control 3D scenes (specifically, rotating colored cubes) in real time.

## Goal
The primary goal of this project is to demonstrate how to bridge a fast, compiled graphics API (Metal) with a dynamic scripting language (JavaScript). This provides a flexible playground where developers or artists can instantly see the results of their code without needing to recompile the entire Swift application, creating an ideal environment for rapid prototyping, creative coding, and educational purposes.

## Architecture & Design
The application is structured into three main layers:

1. **User Interface (SwiftUI):** A split-pane macOS layout containing a live Metal canvas and a live JavaScript text editor. It provides controls to run code, pause/resume animations, and reload the scene.
2. **Graphics Engine (Metal & MetalKit):** A custom `Renderer` class handles the graphics pipeline, vertex processing, shader execution, and instanced drawing of 3D cubes. It calculates camera projections and model transformations (such as continuous rotation).
3. **Scripting Engine (QuickJS):** A C-based bridge (`QuickJSBridge.c/.h`) embeds the QuickJS runtime into the Swift app. It exposes native Swift functions to the JavaScript environment, such as the `drawCube` callback, allowing JS scripts to command the Metal renderer.

## Libraries and Frameworks Used
- **SwiftUI:** For building the modern, reactive macOS user interface.
- **Metal / MetalKit:** Apple's low-level, hardware-accelerated graphics API for rendering 3D graphics.
- **QuickJS:** A small and embeddable JavaScript engine, used to parse and execute user-provided scripts safely and quickly.
- **simd:** Used for high-performance vectorized math operations, specifically for 3D matrix transformations (translation, rotation, and projection).

## What You Can Do With It
You can interactively populate the 3D scene by writing JavaScript in the editor. 

**Exposed API:**
- `drawCube(x, y, size)`: Renders a cube at the specified `(x, y)` coordinates in 3D space with the given `size`.

**Example Usage:**
You can write loops, algorithms, or generative scripts to create complex structures:

```javascript
// A simple grid of cubes
for (let x = -1; x <= 1; x=x+0.5) {
    for (let y = -1; y <= 1; y=y+0.5) {
        drawCube(x, y, 0.3);
    }
}
```

**Features:**
- **Live Execution:** Pressing `Run` (or `Cmd + R`) executes the JavaScript code and **adds** the new cubes to the existing scene. You can stack scripts to build complex shapes layer by layer.
- **Real-time Animation Control:** Pause and resume the continuous cube rotation to inspect the scene.
- **Scene Reloading:** Pressing `Reload` clears all objects from the scene and executes the current script from scratch.
- **Load & Save Scripts:** Native macOS dialogs allow you to open `.js` files from your computer and save your editor's code directly to the filesystem.

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
