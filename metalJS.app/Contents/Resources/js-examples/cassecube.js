// js-examples/cassecube.js
console.log("Starting 3D Breakout (Casse Cube)...");

// Game Settings
const PADDLE_WIDTH = 0.5;
const PADDLE_HEIGHT = 0.05;
const PADDLE_Y = -0.9;
const BALL_SIZE = 0.05;
const BRICK_ROWS = 4;
const BRICK_COLS = 6;
const BRICK_WIDTH = 0.3;
const BRICK_HEIGHT = 0.1;
const AREA_WIDTH = 2.0;
const AREA_HEIGHT = 2.0;

// Game State
const state = {
    paddleX: 0,
    ball: {
        x: 0,
        y: -0.5,
        vx: 0.015,
        vy: 0.015,
        size: BALL_SIZE
    },
    bricks: [],
    score: 0,
    gameOver: false
};

// Initialize Bricks
function initBricks() {
    state.bricks = [];
    const startX = -0.85;
    const startY = 0.8;
    for (let r = 0; r < BRICK_ROWS; r++) {
        for (let c = 0; c < BRICK_COLS; c++) {
            state.bricks.push({
                x: startX + c * (BRICK_WIDTH + 0.05),
                y: startY - r * (BRICK_HEIGHT + 0.05),
                active: true
            });
        }
    }
}

initBricks();

// Camera Setup
setCamera(0, 0, 5, 0, 0, 0);

// Handle Trackpad Events (Paddle Movement)
globalThis._onEvent = function(type, x, y) {
    if (type === "scroll") {
        state.paddleX += x * 0.02;
        // Clamp paddle to boundaries
        const limit = (AREA_WIDTH / 2) - (PADDLE_WIDTH / 2);
        if (state.paddleX > limit) state.paddleX = limit;
        if (state.paddleX < -limit) state.paddleX = -limit;
    }
};

function update() {
    if (state.gameOver) return;

    // Move Ball
    state.ball.x += state.ball.vx;
    state.ball.y += state.ball.vy;

    // Wall Collisions (Left/Right)
    if (Math.abs(state.ball.x) > (AREA_WIDTH / 2 - state.ball.size / 2)) {
        state.ball.vx *= -1;
    }
    // Wall Collisions (Top)
    if (state.ball.y > (AREA_HEIGHT / 2 - state.ball.size / 2)) {
        state.ball.vy *= -1;
    }
    // Paddle Collision
    if (state.ball.y <= PADDLE_Y + PADDLE_HEIGHT / 2 + state.ball.size / 2 &&
        state.ball.y >= PADDLE_Y - PADDLE_HEIGHT / 2 &&
        state.ball.x >= state.paddleX - PADDLE_WIDTH / 2 &&
        state.ball.x <= state.paddleX + PADDLE_WIDTH / 2) {
        
        state.ball.vy = Math.abs(state.ball.vy); // Ensure it goes up
        // Add some spin based on where it hit the paddle
        const hitPoint = (state.ball.x - state.paddleX) / (PADDLE_WIDTH / 2);
        state.ball.vx = hitPoint * 0.02;
    }

    // Brick Collisions
    for (let brick of state.bricks) {
        if (!brick.active) continue;

        if (state.ball.x >= brick.x - BRICK_WIDTH / 2 &&
            state.ball.x <= brick.x + BRICK_WIDTH / 2 &&
            state.ball.y >= brick.y - BRICK_HEIGHT / 2 &&
            state.ball.y <= brick.y + BRICK_HEIGHT / 2) {
            
            brick.active = false;
            state.ball.vy *= -1;
            state.score += 10;
            break;
        }
    }

    // Game Over Check
    if (state.ball.y < -1.1) {
        console.log("Game Over! Score: " + state.score);
        // Reset game
        state.ball.x = 0;
        state.ball.y = -0.5;
        state.ball.vx = 0.015;
        state.ball.vy = 0.015;
        initBricks();
        state.score = 0;
    }
}

function draw() {
    clearCubes();

    // Draw Paddle
    drawCube(state.paddleX, PADDLE_Y, 0, PADDLE_WIDTH);
    // Draw Ball
    drawCube(state.ball.x, state.ball.y, 0, state.ball.size);
    // Draw Bricks
    for (let brick of state.bricks) {
        if (brick.active) {
            drawCube(brick.x, brick.y, 0, BRICK_WIDTH);
        }
    }
    
    // Draw "Walls" (optional markers)
    drawCube(-1, 0, 0, 0.01);
    drawCube(1, 0, 0, 0.01);
}

function gameLoop(timestamp) {
    update();
    draw();
    requestAnimationFrame(gameLoop);
}

// Start game
requestAnimationFrame(gameLoop);

console.log("Casse Cube Running!");
