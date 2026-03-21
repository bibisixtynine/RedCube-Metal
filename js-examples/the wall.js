// The Wall
setCamera(0, 12, 30, 0, 0, 0);
cameraMode('cinematic')


// 1. Floor
let floor = spawn('box', 'Floor')
    .setScale(50, 1, 59)
    .setPosition(0, 0, 0)
    .setColor(0.6, 0.4, 0, 1, 0, 0.1) 
    .setPhysics('static')
	.lock();


// 2. Wall
function Wall(dx,dz,l,h) {

	for (let x=-l/2; x<l/2; x++) {
  		for (let y=1; y<h; y++) {
			spawn('box')
				.setPosition(x+dx+(y%2)/2, y, dz)
				.setPhysics('dynamic')
				.setColor(Math.random(),Math.random(),Math.random())
  		}
	}
}

Wall(0,0,20,20)

// 3. ball

let ball = spawn('sphere','ball')
	.setPosition(0,1.1,20)
	.setPhysics('dynamic')

    
ball.setVelocity(0,12,-11)



