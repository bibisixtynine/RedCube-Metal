// --- PLUIE DE CUBES (Version Premium) ---
// Sol épuré, gravité, et contrôle caméra au trackpad.

let camDist = 25;
let camRotX = 0.5;
let camRotY = 0;

function updateCamera() {
    let px = camDist * Math.cos(camRotX) * Math.sin(camRotY);
    let py = camDist * Math.sin(camRotX);
    let pz = camDist * Math.cos(camRotX) * Math.cos(camRotY);
    setCamera(px, py, pz, 0, 0, 0);
}

updateCamera();

// 1. Sol épuré (Rectangle arrondi peu épais)
let floor = spawn('box', 'Floor')
    .setScale(25, 0.2, 25)
    .setPosition(0, -5, 0)
    .setColor(0.6, 0.6, 0.7, 1, 0, 0.1) // Gris clair non-métallique
    .setPhysics('static');

let cubes = [];
let frameCount = 0;

function spawnCube() {
    let r = Math.random(), g = Math.random(), b = Math.random();
    let x = (Math.random() - 0.5) * 15;
    let z = (Math.random() - 0.5) * 15;
    
    let cube = spawn('box')
        .setPosition(x, 20, z)
        .setRotation(Math.random() * 6, Math.random() * 6, Math.random() * 6)
        .setColor(r, g, b, 1, 0.8, 0.2)
        .setScale(0.6, 0.6, 0.6)
        .setPhysics('dynamic');
    
    cubes.push(cube);
    if (cubes.length > 100) {
        let old = cubes.shift();
        old.remove();
    }
}

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

function loop(t) {
    frameCount++;
    if (frameCount % 5000 === 0) {
        spawnCube();
    }
    requestAnimationFrame(loop);
}

console.log("Interaction prête ! Utilisez le trackpad pour pivoter (drag) et zoomer (pinch).");
loop(0);
