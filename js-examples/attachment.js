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



// 2. Gestion des événements (Zoom et Rotation)
// Le système appelle automatiquement _onEvent(type, x, y)
globalThis._onEvent = function(type, x, y) {
    if (type === 'drag') {
        camRotY -= x * 0.01;
        camRotX += y * 0.01;
        // Limiter la rotation X pour ne pas passer sous le sol
        if (camRotX < 0.1) camRotX = 0.1;
        if (camRotX > 1.4) camRotX = 1.4;
    } else if (type === 'zoom') {
        camDist -= x * 10;
        if (camDist < 5) camDist = 5;
        if (camDist > 50) camDist = 50;
    } else if (type === 'scroll') {
        // Optionnel : utiliser le scroll vertical pour le zoom alternatif
        camDist -= y * 0.1;
        if (camDist < 5) camDist = 5;
        if (camDist > 50) camDist = 50;
    }
    updateCamera();
};


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
