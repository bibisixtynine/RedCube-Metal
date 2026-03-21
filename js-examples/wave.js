// --- EXEMPLE WAVE ---
// Une vague mathématique de cubes.

let cubes = [];
let size = 10;

for (let x = -size; x <= size; x++) {
    for (let z = -size; z <= size; z++) {
        let cube = spawn('box')
            .setPosition(x, 0, z)
            .setScale(0.8, 0.8, 0.8);
        
        // Stocker les coordonnées initiales sur l'objet
        cube.ox = x;
        cube.oz = z;
        cubes.push(cube);
    }
}

setCamera(15, 15, 15, 0, 0, 0);

function loop(t) {
    let time = t * 0.002;
    cubes.forEach(c => {
        let dist = Math.sqrt(c.ox*c.ox + c.oz*c.oz);
        let y = Math.sin(dist * 0.5 - time) * 2;
        
        // Couleur basée sur la hauteur
        let r = (y + 2) / 4;
        
        c.setPosition(c.ox, y, c.oz)
         .setColor(r, 0.3, 1-r, 1, 0.5, 0.5);
    });
    requestAnimationFrame(loop);
}

loop(0);
