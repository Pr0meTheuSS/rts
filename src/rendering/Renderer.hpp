#ifndef RENDERER_HPP
#define RENDERER_HPP

#include <raylib.h>
#include <btBulletDynamicsCommon.h>
#include <vector>
#include "physics/Vehicle.hpp"
#include "physics/Terrain.hpp"

struct TrailPoint {
    Vector3 pos;
};

class Renderer {
public:
    Renderer();
    ~Renderer();

    void loadModels();
    void drawTerrain(const Terrain& terrain);
    void drawVehicle(const btTransform& transform, Model chassisModel);
    void drawWheels(Vehicle& vehicle, std::vector<TrailPoint> trails[4]);
    void drawHUD(float speedKmh);

private:
    void drawWheel(const Vector3& pos, const btMatrix3x3& basis);
    void drawTrails(std::vector<TrailPoint> trails[4]);
    void applyAntiRoll(Vehicle& vehicle);

    static const int MAX_TRAIL_POINTS = 500;
};

#endif // RENDERER_HPP
#ifndef RENDERER_HPP
#define RENDERER_HPP

#include <raylib.h>
#include <btBulletDynamicsCommon.h>
#include <vector>
#include "physics/Vehicle.hpp"
#include "physics/Terrain.hpp"

struct TrailPoint {
    Vector3 pos;
};

class Renderer {
public:
    Renderer();
    ~Renderer();

    void loadModels();
    void drawTerrain(const Terrain& terrain);
    void drawVehicle(const btTransform& transform, Model chassisModel);
    void drawWheels(Vehicle& vehicle, std::vector<TrailPoint> trails[4]);
    void drawHUD(float speedKmh);

private:
    void drawWheel(const Vector3& pos, const btMatrix3x3& basis);
    void drawTrails(std::vector<TrailPoint> trails[4]);
    void applyAntiRoll(Vehicle& vehicle);

    static const int MAX_TRAIL_POINTS = 500;
};

#endif // RENDERER_HPP
