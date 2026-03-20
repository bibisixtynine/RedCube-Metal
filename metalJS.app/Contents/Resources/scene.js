// scene.js
console.log("Starting JS scene...");

// A simple grid of cubes
for (let x = -1; x <= 1; x=x+0.5) {
    for (let y = -1; y <= 1; y=y+0.5) {
        drawCube(x, y, 0.3);
    }
}

console.log("Cubes registered!");
