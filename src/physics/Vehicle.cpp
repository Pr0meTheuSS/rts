#include "Vehicle.hpp"

Vehicle::Vehicle(btDynamicsWorld* world, const btVector3& startPosition) {
    createChassis(startPosition);
    createVehicle(world);
    addWheels();
}

Vehicle::~Vehicle() = default;

void Vehicle::createChassis(const btVector3& startPosition) {
    auto* chassisShape = new btBoxShape(btVector3(1, 0.5, 2));

    btTransform start;
    start.setIdentity();
    start.setOrigin(startPosition);

    btScalar mass = 1500;
    btVector3 inertia(0, 0, 0);
    chassisShape->calculateLocalInertia(mass, inertia);

    auto* ms = new btDefaultMotionState(start);

    btRigidBody::btRigidBodyConstructionInfo ci(mass, ms, chassisShape, inertia);
    chassisBody_ = std::make_unique<btRigidBody>(ci);
    chassisBody_->setActivationState(DISABLE_DEACTIVATION);

    btTransform comOffset;
    comOffset.setIdentity();
    comOffset.setOrigin(btVector3(0, 0.0f, 0.0f));
    chassisBody_->setCenterOfMassTransform(chassisBody_->getWorldTransform() * comOffset);
}

void Vehicle::createVehicle(btDynamicsWorld* world) {
    tuning_.m_suspensionStiffness = 35.0f;
    tuning_.m_suspensionDamping = 0.8f;
    tuning_.m_suspensionCompression = 4.5f;
    tuning_.m_frictionSlip = 0.9f;

    raycaster_ = std::make_unique<btDefaultVehicleRaycaster>(world);
    vehicle_ = std::make_unique<btRaycastVehicle>(tuning_, chassisBody_.get(), raycaster_.get());

    world->addVehicle(vehicle_.get());
    vehicle_->setCoordinateSystem(0, 1, 2);
}

void Vehicle::addWheels() {
    btVector3 points[4] = {
        btVector3(-1, 0, 2),
        btVector3(1, 0, 2),
        btVector3(-1, 0, -2),
        btVector3(1, 0, -2)
    };

    for (int i = 0; i < 4; i++) {
        vehicle_->addWheel(points[i], btVector3(0, -1, 0), btVector3(-1, 0, 0), 0.2f, 0.7f, tuning_, i < 2);
    }

    for (int i = 0; i < 4; i++) {
        auto& w = vehicle_->getWheelInfo(i);
        if (i < 2) {
            w.m_frictionSlip = 0.9f;
            w.m_rollInfluence = 0.1f;
        } else {
            w.m_rollInfluence = 0.15f;
        }
    }
}

void Vehicle::applyEngineForce(float force, int wheelIndex) {
    vehicle_->applyEngineForce(force, wheelIndex);
}

void Vehicle::setBrake(float brake, int wheelIndex) {
    vehicle_->setBrake(brake, wheelIndex);
}

void Vehicle::setSteeringValue(float steering, int wheelIndex) {
    vehicle_->setSteeringValue(steering, wheelIndex);
}

void Vehicle::updateWheelTransform(int wheelIndex, bool interpolated) {
    vehicle_->updateWheelTransform(wheelIndex, interpolated);
}

int Vehicle::getNumWheels() const {
    return vehicle_->getNumWheels();
}

const btRaycastVehicle::btWheelInfo& Vehicle::getWheelInfo(int index) const {
    return vehicle_->getWheelInfo(index);
}

btRigidBody* Vehicle::getChassisBody() const {
    return chassisBody_.get();
}

btRaycastVehicle* Vehicle::getVehicle() const {
    return vehicle_.get();
}
#include "Vehicle.hpp"

Vehicle::Vehicle(btDynamicsWorld* world, const btVector3& startPosition) {
    createChassis(startPosition);
    createVehicle(world);
    addWheels();
}

Vehicle::~Vehicle() = default;

void Vehicle::createChassis(const btVector3& startPosition) {
    auto* chassisShape = new btBoxShape(btVector3(1, 0.5, 2));

    btTransform start;
    start.setIdentity();
    start.setOrigin(startPosition);

    btScalar mass = 1500;
    btVector3 inertia(0, 0, 0);
    chassisShape->calculateLocalInertia(mass, inertia);

    auto* ms = new btDefaultMotionState(start);

    btRigidBody::btRigidBodyConstructionInfo ci(mass, ms, chassisShape, inertia);
    chassisBody_ = std::make_unique<btRigidBody>(ci);
    chassisBody_->setActivationState(DISABLE_DEACTIVATION);

    btTransform comOffset;
    comOffset.setIdentity();
    comOffset.setOrigin(btVector3(0, 0.0f, 0.0f));
    chassisBody_->setCenterOfMassTransform(chassisBody_->getWorldTransform() * comOffset);
}

void Vehicle::createVehicle(btDynamicsWorld* world) {
    tuning_.m_suspensionStiffness = 35.0f;
    tuning_.m_suspensionDamping = 0.8f;
    tuning_.m_suspensionCompression = 4.5f;
    tuning_.m_frictionSlip = 0.9f;

    raycaster_ = std::make_unique<btDefaultVehicleRaycaster>(world);
    vehicle_ = std::make_unique<btRaycastVehicle>(tuning_, chassisBody_.get(), raycaster_.get());

    world->addVehicle(vehicle_.get());
    vehicle_->setCoordinateSystem(0, 1, 2);
}

void Vehicle::addWheels() {
    btVector3 points[4] = {
        btVector3(-1, 0, 2),
        btVector3(1, 0, 2),
        btVector3(-1, 0, -2),
        btVector3(1, 0, -2)
    };

    for (int i = 0; i < 4; i++) {
        vehicle_->addWheel(points[i], btVector3(0, -1, 0), btVector3(-1, 0, 0), 0.2f, 0.7f, tuning_, i < 2);
    }

    for (int i = 0; i < 4; i++) {
        auto& w = vehicle_->getWheelInfo(i);
        if (i < 2) {
            w.m_frictionSlip = 0.9f;
            w.m_rollInfluence = 0.1f;
        } else {
            w.m_rollInfluence = 0.15f;
        }
    }
}

void Vehicle::applyEngineForce(float force, int wheelIndex) {
    vehicle_->applyEngineForce(force, wheelIndex);
}

void Vehicle::setBrake(float brake, int wheelIndex) {
    vehicle_->setBrake(brake, wheelIndex);
}

void Vehicle::setSteeringValue(float steering, int wheelIndex) {
    vehicle_->setSteeringValue(steering, wheelIndex);
}

void Vehicle::updateWheelTransform(int wheelIndex, bool interpolated) {
    vehicle_->updateWheelTransform(wheelIndex, interpolated);
}

int Vehicle::getNumWheels() const {
    return vehicle_->getNumWheels();
}

const btRaycastVehicle::btWheelInfo& Vehicle::getWheelInfo(int index) const {
    return vehicle_->getWheelInfo(index);
}

btRigidBody* Vehicle::getChassisBody() const {
    return chassisBody_.get();
}

btRaycastVehicle* Vehicle::getVehicle() const {
    return vehicle_.get();
}
