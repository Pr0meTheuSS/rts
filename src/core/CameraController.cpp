#include "CameraController.hpp"

#include "MathUtils.hpp"

CameraController::CameraController() {
    camera_.fovy = 60;
    camera_.up = {0, 1, 0};
}

void CameraController::update(const btTransform& vehicleTransform) {
    Vector3 pos = MathUtils::BtToRl(vehicleTransform.getOrigin());
    Vector3 forward = MathUtils::BtForward(vehicleTransform);
    Vector3 up = MathUtils::BtUp(vehicleTransform);

    float dist = 8.0f;
    float height = 3.0f;

    camera_.target = pos;
    camera_.position = {pos.x - forward.x * dist + up.x * height, pos.y - forward.y * dist + up.y * height, pos.z - forward.z * dist + up.z * height};
}

Camera3D CameraController::getCamera() const {
    return camera_;
}
