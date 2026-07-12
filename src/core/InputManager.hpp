#ifndef INPUT_MANAGER_HPP
#define INPUT_MANAGER_HPP

#include <raylib.h>

struct InputState {
    float engineForce = 0.0f;
    float brake = 0.0f;
    float steering = 0.0f;
    bool handbrake = false;
};

class InputManager {
public:
    InputState getInput() const;
};

#endif // INPUT_MANAGER_HPP
#ifndef INPUT_MANAGER_HPP
#define INPUT_MANAGER_HPP

#include <raylib.h>

struct InputState {
    float engineForce = 0.0f;
    float brake = 0.0f;
    float steering = 0.0f;
    bool handbrake = false;
};

class InputManager {
public:
    InputState getInput() const;
};

#endif // INPUT_MANAGER_HPP
