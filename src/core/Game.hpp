#ifndef GAME_HPP
#define GAME_HPP

#include <raylib.h>

#include <memory>
#include <vector>

#include "core/CameraController.hpp"
#include "core/InputManager.hpp"
#include "physics/PhysicsWorld.hpp"
#include "physics/Terrain.hpp"
#include "physics/Vehicle.hpp"
#include "rendering/Renderer.hpp"

class Game {
   public:
    Game();
    ~Game();
    void run();

   private:
    void init();
    void update(float deltaTime);
    void render();
    void processInput();

    std::unique_ptr<PhysicsWorld> physicsWorld_;
    std::unique_ptr<Vehicle> vehicle_;
    std::unique_ptr<Terrain> terrain_;
    InputManager inputManager_;
    CameraController cameraController_;
    Renderer renderer_;
    Model chassisModel_;
    std::vector<TrailPoint> trails_[4];
    bool initialized_ = false;
};

#endif  // GAME_HPP
