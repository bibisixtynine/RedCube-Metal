// Vague de cubes dynamique
let grid = [];
let SIZE = 6;

for (let x = -SIZE; x <= SIZE; x++) {
    for (let z = -SIZE; z <= SIZE; z++) {
        let id = spawn('box');
        setScale(id, 0.8, 0.1, 0.8);
        grid.push({id, x, z});
    }
}

setCamera(0, 15, 20, 0, 0, 0);

function loop(t) {
    grid.forEach(cell => {
        let dist = Math.sqrt(cell.x*cell.x + cell.z*cell.z);
        let y = Math.sin(t * 0.003 - dist * 0.7) * 2;
        setPosition(cell.id, cell.x, y, cell.z);
        
        // Couleur changeante selon la hauteur
        let r = (y + 2) / 4;
        let b = 1 - r;
        setColor(cell.id, r, 0.2, b, 1, 0.5, 0.3);
    });
    requestAnimationFrame(loop);
}

console.log("Vague de cubes lancée !");
loop(0);
