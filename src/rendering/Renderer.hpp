#ifndef RENDERER_HPP
#define RENDERER_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>

#include <vector>

#include "physics/Terrain.hpp"
#include "physics/Vehicle.hpp"

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

#endif  // RENDERER_HPP
