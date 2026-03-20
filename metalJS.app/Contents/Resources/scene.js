// scene.js
console.log("Starting Interactive JS Scene...");

// Camera State
let state = {
    dist: 5.0,
    rotX: 0.5,
    rotY: 0.5
};

function updateCamera() {
    const px = state.dist * Math.cos(state.rotY) * Math.sin(state.rotX);
    const py = state.dist * Math.sin(state.rotY);
    const pz = state.dist * Math.cos(state.rotY) * Math.cos(state.rotX);
    
    setCamera(px, py, pz, 0, 0, 0);
}

// Handle Trackpad Events
globalThis._onEvent = function(type, x, y) {
    if (type === "scroll") {
        state.rotX += x * 0.01;
        state.rotY -= y * 0.01;
        
        // Clamp vertical rotation to avoid flipping
        const limit = Math.PI / 2 - 0.1;
        if (state.rotY > limit) state.rotY = limit;
        if (state.rotY < -limit) state.rotY = -limit;
        
    } else if (type === "zoom") {
        state.dist -= x * 5.0; // magnification delta x is the scale
        if (state.dist < 0.5) state.dist = 0.5;
        if (state.dist > 20.0) state.dist = 20.0;
    }
    
    updateCamera();
};

// Initial camera setup
updateCamera();

// Draw a grid of cubes
for (let x = -1; x <= 1; x += 0.5) {
    for (let y = -1; y <= 1; y += 0.5) {
        for (let z = -1; z <= 1; z += 0.5) {
            drawCube(x, y, z, 0.1);
        }
    }
}

console.log("Interactive Scene Ready!");
