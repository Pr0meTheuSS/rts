#ifndef PHYSICS_WORLD_HPP
#define PHYSICS_WORLD_HPP

#include <btBulletDynamicsCommon.h>

#include <memory>

class PhysicsWorld {
   public:
    PhysicsWorld();
    ~PhysicsWorld();

    void stepSimulation(float deltaTime);
    btDynamicsWorld* getWorld() const;

   private:
    std::unique_ptr<btDefaultCollisionConfiguration> config_;
    std::unique_ptr<btCollisionDispatcher> dispatcher_;
    std::unique_ptr<btDbvtBroadphase> broadphase_;
    std::unique_ptr<btSequentialImpulseConstraintSolver> solver_;
    std::unique_ptr<btDiscreteDynamicsWorld> world_;
};

#endif  // PHYSICS_WORLD_HPP
