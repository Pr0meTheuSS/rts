#ifndef VEHICLE_HPP
#define VEHICLE_HPP

#include <BulletDynamics/Vehicle/btRaycastVehicle.h>
#include <btBulletDynamicsCommon.h>

#include <memory>

class Vehicle {
   public:
    Vehicle(btDynamicsWorld* world, const btVector3& startPosition);
    ~Vehicle();

    void applyEngineForce(float force, int wheelIndex);
    void setBrake(float brake, int wheelIndex);
    void setSteeringValue(float steering, int wheelIndex);
    void updateWheelTransform(int wheelIndex, bool interpolated);
    int getNumWheels() const;
    const btWheelInfo& getWheelInfo(int index) const;
    btRigidBody* getChassisBody() const;
    btRaycastVehicle* getVehicle() const;

   private:
    void createChassis(const btVector3& startPosition);
    void createVehicle(btDynamicsWorld* world);
    void addWheels();

    std::unique_ptr<btRigidBody> chassisBody_;
    std::unique_ptr<btDefaultVehicleRaycaster> raycaster_;
    std::unique_ptr<btRaycastVehicle> vehicle_;
    btRaycastVehicle::btVehicleTuning tuning_;
};

#endif  // VEHICLE_HPP
