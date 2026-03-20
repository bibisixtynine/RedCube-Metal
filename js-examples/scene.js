// scene.js
console.log("Starting Animated JS Scene...");

// Camera/Animation State
const state = {
    dist: 5.0,
    rotX: 0.5,
    rotY: 0.5,
    time: 0
};

function updateCamera() {
    const px = state.dist * Math.cos(state.rotY) * Math.sin(state.rotX);
    const py = state.dist * Math.sin(state.rotY);
    const pz = state.dist * Math.cos(state.rotY) * Math.cos(state.rotX);
    setCamera(px, py, pz, 0, 0, 0);
}

// Handle Trackpad Events (Persistent)
globalThis._onEvent = function(type, x, y) {
    if (type === "scroll") {
        state.rotX += x * 0.01;
        state.rotY -= y * 0.01;
        const limit = Math.PI / 2 - 0.1;
        if (state.rotY > limit) state.rotY = limit;
        if (state.rotY < -limit) state.rotY = -limit;
    } else if (type === "zoom") {
        state.dist -= x * 5.0;
        if (state.dist < 0.5) state.dist = 0.5;
        if (state.dist > 20.0) state.dist = 20.0;
    }
    updateCamera();
};

function animate(timestamp) {
    state.time += 0.02;
    
    // 1. Clear previous frames
    clearCubes();
    
    // 2. Update Camera (optional, can be done once)
    updateCamera();
    
    // 3. Draw animated wave of cubes
    for (let x = -1; x <= 1; x += 0.2) {
        for (let z = -1; z <= 1; z += 0.2) {
            // Procedural wave height
            const d = Math.sqrt(x*x + z*z);
            const y = Math.sin(d * 4 - state.time) * 0.3;
            
            drawCube(x, y, z, 0.1);
        }
    }
    
    // 4. Schedule next frame
    requestAnimationFrame(animate);
}

// Start the animation loop
animate(0);

console.log("Animation Loop Running!");
