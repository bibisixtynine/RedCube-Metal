// js-examples/default-example.js
console.log("Loading Default Example...");

// Simple rotation state
let time = 0;

function animate(timestamp) {
    time += 0.02;
    
    // Clear screen
    clearCubes();
    
    // Set fixed camera
    setCamera(3, 3, 3, 0, 0, 0);
    
    // Draw a single rotating-ish cube (the rotation is handled by the Swift renderer auto-rotation)
    // Here we just place it at the center
    drawCube(0, 0, 0, 1.0);
    
    // Draw some satellite cubes
    const r = 1.5;
    drawCube(Math.cos(time) * r, 0, Math.sin(time) * r, 0.2);
    drawCube(0, Math.sin(time * 0.7) * r, Math.cos(time * 0.7) * r, 0.2);
    
    requestAnimationFrame(animate);
}

// Start animation
animate(0);

console.log("Default Example Running!");
