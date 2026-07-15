#include "Game.hpp"
#include "core/MathUtils.hpp"
#include <algorithm>
#include <cmath>

Game::Game() = default;
Game::~Game() = default;

void Game::init() {
    physicsWorld_ = std::make_unique<PhysicsWorld>();
    terrain_ = std::make_unique<Terrain>(physicsWorld_->getWorld());
    vehicle_ = std::make_unique<Vehicle>(physicsWorld_->getWorld(), btVector3(3, 5, 3));
    chassisModel_ = LoadModel("assets/subaru/subaru.glb");
    initialized_ = true;
}

void Game::run() {
    InitWindow(1280, 720, "stable vehicle terrain");
    SetTargetFPS(60);
    init();

    while (!WindowShouldClose()) {
        float deltaTime = 1.0f / 60.0f;
        update(deltaTime);
        render();
    }

    CloseWindow();
}

void Game::update(float deltaTime) {
    if (!initialized_) return;

    physicsWorld_->stepSimulation(deltaTime);
    processInput();

    btTransform t;
    vehicle_->getChassisBody()->getMotionState()->getWorldTransform(t);
    cameraController_.update(t);
}

void Game::processInput() {
    InputState input = inputManager_.getInput();

    // Smooth steering
    static float currentSteer = 0.0f;
    float steerRate = 0.15f;
    currentSteer += (input.steering - currentSteer) * steerRate;

    vehicle_->setSteeringValue(currentSteer, 0);
    vehicle_->setSteeringValue(currentSteer, 1);

    float speedFactor = 1.0f;
    if (input.steering != 0.0f) speedFactor = 0.7f;

    vehicle_->applyEngineForce(input.engineForce * speedFactor, 2);
    vehicle_->applyEngineForce(input.engineForce * speedFactor, 3);

    if (input.handbrake) {
        vehicle_->setBrake(input.brake, 2);
        vehicle_->setBrake(input.brake, 3);
    } else {
        for (int i = 0; i < 4; i++) vehicle_->setBrake(0, i);
    }
}

void Game::render() {
    if (!initialized_) return;

    BeginDrawing();
    ClearBackground(RAYWHITE);

    Camera3D cam = cameraController_.getCamera();
    BeginMode3D(cam);

    renderer_.drawTerrain(*terrain_);
    DrawGrid(256, 1);

    btTransform t;
    vehicle_->getChassisBody()->getMotionState()->getWorldTransform(t);
    renderer_.drawVehicle(t, chassisModel_);
    renderer_.drawWheels(*vehicle_, trails_);

    EndMode3D();

    btVector3 vel = vehicle_->getChassisBody()->getLinearVelocity();
    float speedKmh = vel.length() * 3.6f;
    renderer_.drawHUD(speedKmh);

    EndDrawing();
}
