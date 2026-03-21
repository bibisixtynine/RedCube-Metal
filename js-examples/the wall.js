// The Wall

cameraMode('cinematic')
setCamera(0, 12, 20, 0, 0, 0);


// 1. Floor
let floor = spawn('box', 'Floor')
    .setScale(50, 1, 59)
    .setPosition(0, 0, 0)
    .setColor(0.6, 0.4, 0, 1, 0, 0.1) 
    .setPhysics('static')
	.lock();


// 2. Wall
for (let x=-5; x<5; x++) {
  for (let y=1; y<5; y++) {
	spawn('box')
		.setPosition(x*1.1,y*1.01,0)
		.setPhysics('dynamic')
		.setColor(Math.random(),Math.random(),Math.random())
  }
}

// 3. ball

let ball = spawn('sphere','ball')
	.setPosition(0,1.1,20)

    
ball.setVelocity(0,10,10)



