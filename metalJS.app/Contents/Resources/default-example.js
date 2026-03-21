// --- PLUIE DE CUBES (Version Premium) ---
// Sol épuré, gravité, et contrôle caméra cinématique.

// Utiliser le nouveau mode caméra pour un orbit automatique facile
setCamera(0, 10, 15, 0, 0, 0);

cameraMode('cinematic');

let floor = spawn('box', 'Floor')
    .setScale(25, 0.2, 25)
    .setPosition(0, 0, 0)
    .setColor(0.0, 0.4, 0.0, 1, 0, 0.1) // Gris clair non-métallique
    .setPhysics('static')
    .lock();

let cube1 = spawn('box','cube1')
	.setPosition(0,2,0)
	.setColor(1,0,0,1)
	.setPhysics('dynamic')

let cube2 = spawn('box','cube2')
	.setPosition(-2,2,0)
	.setColor(1,0.5,0.5,1)
	.setPhysics('dynamic')

let sphere = spawn('sphere','sphere')
	.setPosition(2,2,0)
	.setColor(1,1,0,.4)
	.setPhysics('dynamic')

