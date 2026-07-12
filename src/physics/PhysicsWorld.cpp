#include "PhysicsWorld.hpp"

PhysicsWorld::PhysicsWorld()
    : config_(std::make_unique<btDefaultCollisionConfiguration>()),
      dispatcher_(std::make_unique<btCollisionDispatcher>(config_.get())),
      broadphase_(std::make_unique<btDbvtBroadphase>()),
      solver_(std::make_unique<btSequentialImpulseConstraintSolver>()),
      world_(std::make_unique<btDiscreteDynamicsWorld>(dispatcher_.get(), broadphase_.get(), solver_.get(), config_.get())) {
    world_->setGravity(btVector3(0, -9.81f, 0));
}

PhysicsWorld::~PhysicsWorld() = default;

void PhysicsWorld::stepSimulation(float deltaTime) {
    world_->stepSimulation(deltaTime);
}

btDynamicsWorld* PhysicsWorld::getWorld() const {
    return world_.get();
}
