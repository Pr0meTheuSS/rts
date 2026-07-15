#include "Renderer.hpp"
#include "core/MathUtils.hpp"
#include <rlgl.h>
#include <algorithm>

Renderer::Renderer() = default;
Renderer::~Renderer() = default;

void Renderer::loadModels() {
    // Models are loaded externally
}

void Renderer::drawTerrain(const Terrain& terrain) {
    terrain.draw();
}

void Renderer::drawVehicle(const btTransform& transform, Model chassisModel) {
    Vector3 pos = MathUtils::BtToRl(transform.getOrigin());
    const btMatrix3x3& b = transform.getBasis();

    float m[16];
    m[0] = b[0][0]; m[4] = b[0][1]; m[8] = b[0][2]; m[12] = pos.x;
    m[1] = b[1][0]; m[5] = b[1][1]; m[9] = b[1][2]; m[13] = pos.y;
    m[2] = b[2][0]; m[6] = b[2][1]; m[10] = b[2][2]; m[14] = pos.z;
    m[3] = 0; m[7] = 0; m[11] = 0; m[15] = 1;

    rlPushMatrix();
    rlMultMatrixf(m);
    rlRotatef(180.0f, 0, 1, 0);
    DrawModel(chassisModel, (Vector3){0, 0, 0}, 2.5f, WHITE);
    rlPopMatrix();
}

void Renderer::drawWheels(Vehicle& vehicle, std::vector<TrailPoint> trails[4]) {
    applyAntiRoll(vehicle);

    for (int i = 0; i < vehicle.getNumWheels(); i++) {
        vehicle.updateWheelTransform(i, true);
        auto tr = vehicle.getWheelInfo(i).m_worldTransform;
        btVector3 p = tr.getOrigin();
        Vector3 pos = MathUtils::BtToRl(p);

        trails[i].push_back({pos});
        if (trails[i].size() > MAX_TRAIL_POINTS) {
            trails[i].erase(trails[i].begin());
        }

        const btMatrix3x3& b = vehicle.getWheelInfo(i).m_worldTransform.getBasis();
        drawWheel(pos, b);
    }

    drawTrails(trails);
}

void Renderer::drawWheel(const Vector3& pos, const btMatrix3x3& basis) {
    rlPushMatrix();

    float m[16];
    m[0] = basis[0][0]; m[4] = basis[0][1]; m[8] = basis[0][2]; m[12] = pos.x + 0.15f;
    m[1] = basis[1][0]; m[5] = basis[1][1]; m[9] = basis[1][2]; m[13] = pos.y;
    m[2] = basis[2][0]; m[6] = basis[2][1]; m[10] = basis[2][2]; m[14] = pos.z;
    m[3] = 0; m[7] = 0; m[11] = 0; m[15] = 1;

    rlMultMatrixf(m);
    rlRotatef(90.0f, 0, 0, 1);

    DrawCylinder({0, 0, 0}, 0.5f, 0.5f, 0.3f, 16, DARKGRAY);
    DrawCylinderWires({0, 0, 0}, 0.5f, 0.5f, 0.3f, 16, BLACK);

    rlPopMatrix();
}

void Renderer::drawTrails(std::vector<TrailPoint> trails[4]) {
    for (int i = 0; i < 4; i++) {
        for (size_t j = 1; j < trails[i].size(); j++) {
            Vector3 a = trails[i][j - 1].pos;
            Vector3 b = trails[i][j].pos;
            DrawLine3D(a, b, RED);
        }
    }
}

void Renderer::applyAntiRoll(Vehicle& vehicle) {
    auto& wl = vehicle.getWheelInfo(0);
    auto& wr = vehicle.getWheelInfo(1);

    float travelL = wl.m_raycastInfo.m_suspensionLength;
    float travelR = wr.m_raycastInfo.m_suspensionLength;
    float antiRoll = (travelL - travelR) * 8000.0f;

    btRigidBody* chassis = vehicle.getChassisBody();

    if (wl.m_raycastInfo.m_isInContact) {
        chassis->applyForce(btVector3(0, -antiRoll, 0),
            wl.m_raycastInfo.m_contactPointWS - chassis->getCenterOfMassPosition());
    }
    if (wr.m_raycastInfo.m_isInContact) {
        chassis->applyForce(btVector3(0, antiRoll, 0),
            wr.m_raycastInfo.m_contactPointWS - chassis->getCenterOfMassPosition());
    }
}

void Renderer::drawHUD(float speedKmh) {
    DrawText("WASD + SPACE", 20, 20, 20, DARKGRAY);
    DrawText(TextFormat("SPEED  %.1f km/h", speedKmh), 40, 100, 24, BLACK);
}
