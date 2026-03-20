// --- EXEMPLE WAVE ---
// Une vague mathématique de cubes.

let cubes = [];
let size = 10;

for (let x = -size; x <= size; x++) {
    for (let z = -size; z <= size; z++) {
        let id = spawn('box');
        setPosition(id, x, 0, z);
        setScale(id, 0.8, 0.8, 0.8);
        cubes.push({ id: id, x: x, z: z });
    }
}

setCamera(15, 15, 15, 0, 0, 0);

function loop(t) {
    let time = t * 0.002;
    cubes.forEach(c => {
        let dist = Math.sqrt(c.x*c.x + c.z*c.z);
        let y = Math.sin(dist * 0.5 - time) * 2;
        setPosition(c.id, c.x, y, c.z);
        
        // Couleur basée sur la hauteur
        let r = (y + 2) / 4;
        setColor(c.id, r, 0.3, 1-r, 1, 0.5, 0.5);
    });
    requestAnimationFrame(loop);
}

loop(0);
