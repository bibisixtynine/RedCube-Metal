// scene.js
console.log("Starting JS scene...");

// A simple grid of cubes
for (let x = -2; x <= 2; x=x+0.1) {
    for (let y = -2; y <= 2; y=y+0.1) {
        drawCube(x, y, 0.3);
    }
}

console.log("Cubes registered!");
