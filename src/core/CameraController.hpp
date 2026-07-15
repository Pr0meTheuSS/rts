#ifndef CAMERA_CONTROLLER_HPP
#define CAMERA_CONTROLLER_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>

class CameraController {
   public:
    CameraController();
    void update(const btTransform& vehicleTransform);
    Camera3D getCamera() const;

   private:
    Camera3D camera_;
};

#endif  // CAMERA_CONTROLLER_HPP
