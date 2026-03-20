// Interaction et rotation
let core = spawn('box', 'Core');
setScale(core, 2, 2, 2);
setColor(core, 0.2, 0.8, 0.2, 0.8, 0.9, 0.1);

let ring = [];
for (let i = 0; i < 12; i++) {
    let id = spawn('sphere');
    setScale(id, 0.4, 0.4, 0.4);
    ring.push(id);
}

setCamera(10, 10, 10, 0, 0, 0);

let rotationSpeed = 0.001;

globalThis._onEvent = function(type, x, y) {
    if (type === 'scroll') {
        rotationSpeed += x * 0.0001;
        console.log("Vitesse de rotation : " + rotationSpeed);
    }
};

function loop(t) {
    let angle = t * rotationSpeed;
    setRotation(core, angle, angle, 0);
    
    ring.forEach((id, i) => {
        let a = angle + (i / ring.length) * Math.PI * 2;
        setPosition(id, Math.cos(a) * 4, Math.sin(a) * 4, 0);
        setColor(id, 0.5 + Math.sin(a)*0.5, 0.5, 1, 1);
    });
    
    requestAnimationFrame(loop);
}

console.log("Utilisez le scroll pour changer la vitesse !");
loop(0);
