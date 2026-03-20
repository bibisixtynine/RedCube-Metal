// --- EXEMPLE INTERACTIF ---
// Manipulez les objets avec votre trackpad !

let cubes = [];
let count = 5;

// Créer une grille de cubes
for (let x = -count; x <= count; x++) {
    for (let z = -count; z <= count; z++) {
        let id = spawn('box');
        setPosition(id, x * 1.5, 0, z * 1.5);
        setColor(id, 0.4, 0.4, 0.5, 1, 0, 0.8);
        cubes.push({ id: id, ox: x * 1.5, oz: z * 1.5 });
    }
}

setCamera(0, 15, 20, 0, 0, 0);

let lightDist = 1;

globalThis._onEvent = function(type, x, y) {
    if (type === 'drag') {
        // Faire varier la couleur en fonction du drag
        cubes.forEach(c => {
            setColor(c.id, Math.abs(x), Math.abs(y), 0.5, 1, 0, 1);
        });
    } else if (type === 'scroll') {
        // Faire monter/descendre les cubes
        cubes.forEach(c => {
            setPosition(c.id, c.ox, y * 0.1, c.oz);
        });
    }
};

console.log("Bougez le trackpad pour interagir !");
