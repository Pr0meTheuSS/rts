#ifndef TERRAIN_HPP
#define TERRAIN_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>
#include <vector>
#include <memory>

class Terrain {
public:
    Terrain(btDynamicsWorld* world);
    ~Terrain();

    Model getModel() const;
    void draw() const;

private:
    std::vector<float> heightData_;
    std::unique_ptr<btHeightfieldTerrainShape> shape_;
    std::unique_ptr<btRigidBody> body_;
    Model model_;

    void loadHeightmap();
    void createPhysicsBody(btDynamicsWorld* world);
    void generateModel();
};

#endif // TERRAIN_HPP
#ifndef TERRAIN_HPP
#define TERRAIN_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>
#include <vector>
#include <memory>

class Terrain {
public:
    Terrain(btDynamicsWorld* world);
    ~Terrain();

    Model getModel() const;
    void draw() const;

private:
    std::vector<float> heightData_;
    std::unique_ptr<btHeightfieldTerrainShape> shape_;
    std::unique_ptr<btRigidBody> body_;
    Model model_;

    void loadHeightmap();
    void createPhysicsBody(btDynamicsWorld* world);
    void generateModel();
};

#endif // TERRAIN_HPP
