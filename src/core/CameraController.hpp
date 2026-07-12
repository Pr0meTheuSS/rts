#ifndef CAMERA_CONTROLLER_HPP
#define CAMERA_CONTROLLER_HPP

#include <raylib.h>
#include <btBulletDynamicsCommon.h>

class CameraController {
public:
    CameraController();
    void update(const btTransform& vehicleTransform);
    Camera3D getCamera() const;

private:
    Camera3D camera_;
};

#endif // CAMERA_CONTROLLER_HPP
#ifndef CAMERA_CONTROLLER_HPP
#define CAMERA_CONTROLLER_HPP

#include <raylib.h>
#include <btBulletDynamicsCommon.h>

class CameraController {
public:
    CameraController();
    void update(const btTransform& vehicleTransform);
    Camera3D getCamera() const;

private:
    Camera3D camera_;
};

#endif // CAMERA_CONTROLLER_HPP
