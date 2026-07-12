#include "InputManager.hpp"

InputState InputManager::getInput() const {
    InputState state;

    if (IsKeyDown(KEY_W)) state.engineForce = 2500.0f;
    if (IsKeyDown(KEY_S)) state.engineForce = -2500.0f;

    if (IsKeyDown(KEY_A)) state.steering = 0.4f;
    if (IsKeyDown(KEY_D)) state.steering = -0.4f;

    if (IsKeyDown(KEY_SPACE)) {
        state.handbrake = true;
        state.brake = 120.0f;
    }

    return state;
}
#include "InputManager.hpp"

InputState InputManager::getInput() const {
    InputState state;

    if (IsKeyDown(KEY_W)) state.engineForce = 2500.0f;
    if (IsKeyDown(KEY_S)) state.engineForce = -2500.0f;

    if (IsKeyDown(KEY_A)) state.steering = 0.4f;
    if (IsKeyDown(KEY_D)) state.steering = -0.4f;

    if (IsKeyDown(KEY_SPACE)) {
        state.handbrake = true;
        state.brake = 120.0f;
    }

    return state;
}
