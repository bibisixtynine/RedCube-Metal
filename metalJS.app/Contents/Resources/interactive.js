// --- EXEMPLE INTERACTIF ---
// Manipulez les objets avec votre trackpad !

let cubes = [];
let count = 5;

// Créer une grille de cubes
for (let x = -count; x <= count; x++) {
    for (let z = -count; z <= count; z++) {
        let cube = spawn('box')
            .setPosition(x * 1.5, 0, z * 1.5)
            .setColor(0.4, 0.4, 0.5, 1, 0, 0.8);
        
        // On peut stocker des données personnalisées directement sur l'objet !
        cube.ox = x * 1.5;
        cube.oz = z * 1.5;
        cubes.push(cube);
    }
}

setCamera(0, 15, 20, 0, 0, 0);

globalThis._onEvent = function(type, x, y) {
    if (type === 'drag') {
        cubes.forEach(c => {
            c.setColor(Math.abs(x), Math.abs(y), 0.5, 1, 0, 1);
        });
    } else if (type === 'scroll') {
        cubes.forEach(c => {
            c.setPosition(c.ox, y * 0.1, c.oz);
        });
    }
};

console.log("Bougez le trackpad pour interagir !");
