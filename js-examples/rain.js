// --- PLUIE DE CUBES COLORÉS ---
// Un sol quadrillé, de la gravité, et une explosion de couleurs.

setCamera(0, 10, 15, 0, 0, 0);

// 1. Création du sol
let floor = spawn('box', 'Floor')
    .setScale(20, 0.1, 20)
    .setPosition(0, -5, 0)
    .setColor(1, 1, 1, 1, 0, 1)
    .setTexture('grid')
    .setPhysics('static');

let cubes = [];
let frameCount = 0;

function randomColor() {
    return {
        r: Math.random(),
        g: Math.random(),
        b: Math.random()
    };
}

function spawnCube() {
    let color = randomColor();
    
    // Position aléatoire en haut
    let x = (Math.random() - 0.5) * 10;
    let z = (Math.random() - 0.5) * 10;
    let y = 15;
    
    let cube = spawn('box', 'RainCube')
        .setPosition(x, y, z)
        .setColor(color.r, color.g, color.b, 1, 0.5, 0.2)
        .setScale(0.5, 0.5, 0.5)
        .setPhysics('dynamic');
    
    cubes.push({ obj: cube, time: Date.now() });
}

function loop(t) {
    frameCount++;
    
    // Faire tomber un nouveau cube toutes les 10 frames
    if (frameCount % 10 === 0 && cubes.length < 100) {
        spawnCube();
    }
    
    // Nettoyer les vieux cubes qui sont tombés trop bas (pour les perfs)
    // Non nécessaire ici car ils s'arrêtent au sol, mais bonne pratique.
    
    requestAnimationFrame(loop);
}

console.log("C'est parti pour la pluie !");
loop(0);
