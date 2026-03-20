// scene.js
console.log("Starting JS scene...");

// A simple 3D grid of cubes
for (let x = -1; x <= 1; x = x + 0.5) {
    for (let y = -1; y <= 1; y = y + 0.5) {
        for (let z = -1; z <= 1; z = z + 0.5) {
            drawCube(x, y, z, 0.1);
        }
    }
}

console.log("Cubes registered!");
