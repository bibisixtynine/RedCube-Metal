// scene.js
console.log("Starting JS scene...");

// Position the camera at (3, 3, 3) and look at the center (0, 0, 0)
setCamera(3, 3, 3, 0, 0, 0);

// A simple 3D grid of cubes
for (let x = -1; x <= 1; x = x + 0.5) {
    for (let y = -1; y <= 1; y = y + 0.5) {
        for (let z = -1; z <= 1; z = z + 0.5) {
            drawCube(x, y, z, 0.1);
        }
    }
}

console.log("Cubes registered!");
