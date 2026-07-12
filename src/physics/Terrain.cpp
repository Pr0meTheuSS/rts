#include "Terrain.hpp"
#include <rlgl.h>
#include <algorithm>
#include <cmath>

static const int TERRAIN_WIDTH = 256;
static const int TERRAIN_LENGTH = 256;
static const float WORLD_SCALE = 1.0f;
static const float HEIGHT_SCALE = 1.2f;

Terrain::Terrain(btDynamicsWorld* world) {
    loadHeightmap();
    createPhysicsBody(world);
    generateModel();
}

Terrain::~Terrain() = default;

void Terrain::loadHeightmap() {
    Image image = LoadImage("rally_track_heightmap.png");
    heightData_.resize(image.width * image.height);

    const unsigned char* pixels = static_cast<const unsigned char*>(image.data);
    for (int y = 0; y < image.height; ++y) {
        for (int x = 0; x < image.width; ++x) {
            int pixelIndex = x * image.height + y;
            unsigned char val = pixels[pixelIndex * 4];
            float h = (static_cast<float>(val) / 255.0f) * 0.3f;
            heightData_[y * image.width + x] = h;
        }
    }
    UnloadImage(image);
}

void Terrain::createPhysicsBody(btDynamicsWorld* world) {
    shape_ = std::make_unique<btHeightfieldTerrainShape>(
        TERRAIN_WIDTH, TERRAIN_LENGTH,
        heightData_.data(),
        0, 0,
        1, 1,
        PHY_FLOAT,
        true
    );
    shape_->setUseDiamondSubdivision(true);

    btTransform groundTransform;
    groundTransform.setIdentity();

    auto* ms = new btDefaultMotionState(groundTransform);
    btRigidBody::btRigidBodyConstructionInfo ci(0.0f, ms, shape_.get(), btVector3(0, 0, 0));
    ci.m_restitution = 0.3f;
    ci.m_friction = 0.8f;

    body_ = std::make_unique<btRigidBody>(ci);
    world->addRigidBody(body_.get());
}

void Terrain::generateModel() {
    size_t worldWidth = TERRAIN_WIDTH * WORLD_SCALE;
    size_t worldLength = TERRAIN_LENGTH * WORLD_SCALE;

    Image image = GenImageColor(worldWidth, worldLength, WHITE);
    Color* pixels = static_cast<Color*>(image.data);

    for (int y = 0; y < worldWidth; ++y) {
        for (int x = 0; x < worldLength; ++x) {
            float h = heightData_[x * worldWidth + y];
            unsigned char val = static_cast<unsigned char>(h * 255.0f);
            Color c = {val, val, val, val};
            SetPixelColor(&pixels[y + x * worldLength], c, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
        }
    }

    Texture2D texture = LoadTextureFromImage(image);
    Mesh mesh = GenMeshHeightmap(image, (Vector3){static_cast<float>(worldWidth), 3.0f, static_cast<float>(worldLength)});
    model_ = LoadModelFromMesh(mesh);
    model_.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;

    UnloadImage(image);
}

Model Terrain::getModel() const {
    return model_;
}

void Terrain::draw() const {
    DrawModel(model_, (Vector3){-TERRAIN_LENGTH / 2.0f, -1.1f, -TERRAIN_LENGTH / 2.0f}, 1.0f, GRAY);
}
#include "Terrain.hpp"
#include <rlgl.h>
#include <algorithm>
#include <cmath>

static const int TERRAIN_WIDTH = 256;
static const int TERRAIN_LENGTH = 256;
static const float WORLD_SCALE = 1.0f;
static const float HEIGHT_SCALE = 1.2f;

Terrain::Terrain(btDynamicsWorld* world) {
    loadHeightmap();
    createPhysicsBody(world);
    generateModel();
}

Terrain::~Terrain() = default;

void Terrain::loadHeightmap() {
    Image image = LoadImage("rally_track_heightmap.png");
    heightData_.resize(image.width * image.height);

    const unsigned char* pixels = static_cast<const unsigned char*>(image.data);
    for (int y = 0; y < image.height; ++y) {
        for (int x = 0; x < image.width; ++x) {
            int pixelIndex = x * image.height + y;
            unsigned char val = pixels[pixelIndex * 4];
            float h = (static_cast<float>(val) / 255.0f) * 0.3f;
            heightData_[y * image.width + x] = h;
        }
    }
    UnloadImage(image);
}

void Terrain::createPhysicsBody(btDynamicsWorld* world) {
    shape_ = std::make_unique<btHeightfieldTerrainShape>(
        TERRAIN_WIDTH, TERRAIN_LENGTH,
        heightData_.data(),
        0, 0,
        1, 1,
        PHY_FLOAT,
        true
    );
    shape_->setUseDiamondSubdivision(true);

    btTransform groundTransform;
    groundTransform.setIdentity();

    auto* ms = new btDefaultMotionState(groundTransform);
    btRigidBody::btRigidBodyConstructionInfo ci(0.0f, ms, shape_.get(), btVector3(0, 0, 0));
    ci.m_restitution = 0.3f;
    ci.m_friction = 0.8f;

    body_ = std::make_unique<btRigidBody>(ci);
    world->addRigidBody(body_.get());
}

void Terrain::generateModel() {
    size_t worldWidth = TERRAIN_WIDTH * WORLD_SCALE;
    size_t worldLength = TERRAIN_LENGTH * WORLD_SCALE;

    Image image = GenImageColor(worldWidth, worldLength, WHITE);
    Color* pixels = static_cast<Color*>(image.data);

    for (int y = 0; y < worldWidth; ++y) {
        for (int x = 0; x < worldLength; ++x) {
            float h = heightData_[x * worldWidth + y];
            unsigned char val = static_cast<unsigned char>(h * 255.0f);
            Color c = {val, val, val, val};
            SetPixelColor(&pixels[y + x * worldLength], c, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
        }
    }

    Texture2D texture = LoadTextureFromImage(image);
    Mesh mesh = GenMeshHeightmap(image, (Vector3){static_cast<float>(worldWidth), 3.0f, static_cast<float>(worldLength)});
    model_ = LoadModelFromMesh(mesh);
    model_.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;

    UnloadImage(image);
}

Model Terrain::getModel() const {
    return model_;
}

void Terrain::draw() const {
    DrawModel(model_, (Vector3){-TERRAIN_LENGTH / 2.0f, -1.1f, -TERRAIN_LENGTH / 2.0f}, 1.0f, GRAY);
}
