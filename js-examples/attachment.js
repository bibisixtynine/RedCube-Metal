// Simplified Attachment API Example
// This example demonstrates how to parent entities to each other.

// 1. Create a central "Planet"
let planet = spawn('sphere', 'Planet')
    .setPosition(0, 0, 0)
    .setScale(1, 1, 1)
    .setColor(0.2, 0.5, 1, 1, 0.1, 0.3); // Blue planet

// 2. Create a "Moon" and attach it to the Planet
let moon = spawn('sphere', 'Moon')
    .setPosition(2, 0, 0) // Local position relative to planet if attached
    .setScale(0.3, 0.3, 0.3)
    .setColor(0.8, 0.8, 0.8, 1, 0, 0.8) // Gray moon
    .attachTo(planet); // <-- NEW API: Attach moon to planet

// 3. Create a "Satellite" and attach it to the Moon (nested hierarchy!)
let satellite = spawn('box', 'Satellite')
    .setPosition(0.5, 0, 0)
    .setScale(0.1, 0.1, 0.1)
    .setColor(1, 1, 0, 1, 0.8, 0.2) // Gold satellite
    .attachTo(moon); // <-- NEW API: Attach satellite to moon



// Hierarchy created: Planet -> Moon -> Satellite
cameraMode('cinematic');


// Animation logic
let angle = 0;
function update() {
    angle += 0.02;
    
    // Rotating the planet also rotates everything attached to it!
    planet.setRotation(0, angle, 0);
    
    // We can also rotate the moon independently on its own axis
    // moon.setRotation(0, angle * 2, 0);
    
    requestAnimationFrame(update);
}

// Start the animation
update();

console.log("Hierarchy created: Planet -> Moon -> Satellite");
