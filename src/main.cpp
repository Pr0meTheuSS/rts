#include <BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h>
#include <BulletDynamics/Vehicle/btRaycastVehicle.h>
#include <btBulletDynamicsCommon.h>
#include <raylib.h>

#include <algorithm>
#include <cmath>
#include <vector>

#include "rlgl.h"

// // Для рендера: карта высот (должна быть степенью двойки для удобства)
// static const int TERRAIN_MAP_RES = 128;
struct TrailPoint {
    Vector3 pos;
};

std::vector<TrailPoint> trails[4];
static const int MAX_TRAIL_POINTS = 500;
// =========================
// WORLD SETTINGS (ВАЖНО)
// =========================
static const float WORLD_SCALE = 1.0f;
static const float HEIGHT_SCALE = 1.2f;
static const int TERRAIN_WIDTH = 256;
static const int TERRAIN_LENGTH = 256;

// =========================
// BULLET GLOBALS
// =========================
btDynamicsWorld* world;
btRigidBody* chassisBody;
btRaycastVehicle* vehicle;
btVehicleRaycaster* raycaster;

// =========================
// HEIGHT FUNCTION
// =========================
float GetTerrainHeight(float x, float z) {
    return 0;
    float h = 1.2f * sinf(0.08f * x) + 1.2f * cosf(0.06f * z) + 0.4f * sinf(0.03f * (x + z));

    return h;
}

// =========================
// TERRAIN STORAGE
// =========================
std::vector<float> heightData;

// Возвращает {minH, maxH}
std::pair<float, float> GetTerrainHeightRange(float minX, float maxX, float minZ, float maxZ, int stepsPerAxis = 1) {
    float minH = 99999.0f;
    float maxH = -99999.0f;

    float stepX = (maxX - minX) / stepsPerAxis;
    float stepZ = (maxZ - minZ) / stepsPerAxis;

    // Проходим по сетке внутри заданных границ
    for (int i = 0; i <= stepsPerAxis; ++i) {
        float x = minX + i * stepX;

        for (int j = 0; j <= stepsPerAxis; ++j) {
            float z = minZ + j * stepZ;

            float h = GetTerrainHeight(x, z);

            if (h < minH) minH = h;
            if (h > maxH) maxH = h;
        }
    }

    return {minH, maxH};
}
void DrawTrails() {
    for (int i = 0; i < 4; i++) {
        for (size_t j = 1; j < trails[i].size(); j++) {
            Vector3 a = trails[i][j - 1].pos;
            Vector3 b = trails[i][j].pos;

            DrawLine3D(a, b, RED);
        }
    }
}
// Конвертирует Image (grayscale heightmap) в vector<float> для Bullet
std::vector<float> ImageToHeightData(const Image& img, float maxHeight) {
    std::vector<float> heights;
    // Резервируем память: ширина * высота (это количество вершин)
    heights.resize(img.width * img.height);

    const unsigned char* pixels = static_cast<const unsigned char*>(img.data);

    for (int y = 0; y < img.height; ++y) {     // y здесь соответствует оси Z в мире (глубина)
        for (int x = 0; x < img.width; ++x) {  // x здесь соответствует оси X в мире

            // Вычисляем индекс пикселя в линейном массиве
            // Raylib хранит как [row * width + col]
            int pixelIndex = x * img.height + y;

            // Берем яркость.
            // Если картинка RGB, берем R (или среднее R+G+B).
            // Если Grayscale (как мы делали раньше), R, G, B одинаковы.
            unsigned char val = pixels[pixelIndex * 4];  // Умножаем на 4, т.к. формат обычно UNCOMPRESSED_R8G8B8A8

            // Конвертируем 0..255 в 0..maxHeight
            float h = (static_cast<float>(val) / 255.0f) * maxHeight;

            // Сохраняем в массив.
            // ВАЖНО: Порядок должен совпадать с тем, как ты создаешь shape в Bullet.
            // Обычно это: index = z * width + x.
            // В цикле выше 'y' играет роль 'z' (глубины).
            heights[y * img.width + x] = h;
        }
    }

    return heights;
}

// =========================
// RENDER TERRAIN VIA HEIGHTMAP (GenMeshHeightmap)
// =========================
Model GenerateTerrainModel() {
    // Размер мира в мировых координатах (как в физике)
    size_t worldWidth = TERRAIN_WIDTH * WORLD_SCALE;
    size_t worldLength = TERRAIN_LENGTH * WORLD_SCALE;

    Image image = GenImageColor(worldWidth, worldLength, WHITE);

    Color* pixels = static_cast<Color*>(image.data);
    float minH = 0.0f;  // GetTerrainHeightRange(0, worldWidth, 0, worldLength);
    float maxH = 1.0f;

    for (int y = 0; y < worldWidth; ++y) {
        for (int x = 0; x < worldLength; ++x) {
            float h = heightData[x * worldWidth + y];
            // 1. Нормализуем высоту в диапазон [0, 1]
            // Используем глобальные minH и maxH, которые мы посчитали заранее
            float range = maxH - minH;
            if (range <= 0) range = 1.0f;

            float t = (h - minH) / range;
            t = std::clamp(t, 0.0f, 1.0f);

            // 2. Превращаем в байт 0..255
            unsigned char val = static_cast<unsigned char>(h * 255.0f);

            // 3. Создаем цвет.
            // ВАЖНО: Для GRAYSCALE все три канала (R, G, B) должны быть одинаковыми.
            // Тогда формула внутри SetPixelColor вернет ровно val.
            Color c = {val, val, val, val};

            // 4. Записываем
            SetPixelColor(&pixels[y + x * worldLength], c, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
        }
    }

    // Image image = LoadImage("heightmap.png");
    Texture2D texture = LoadTextureFromImage(image);

    // Масштабирование меша:
    // X и Z — размеры мира, Y — высота (подбираем, чтобы выглядело естественно)
    Mesh mesh = GenMeshHeightmap(image, (Vector3){worldWidth, 3.0f, worldLength});

    Model model = LoadModelFromMesh(mesh);
    model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;

    UnloadImage(image);  // данные уже в VRAM как текстура

    return model;
}
// =========================
// TERRAIN BUILD
// =========================
void CreateTerrain(btDynamicsWorld* world) {
    heightData.reserve(TERRAIN_LENGTH * TERRAIN_WIDTH);
    Image image = LoadImage("rally_track_heightmap.png");
    heightData = ImageToHeightData(image, 0.3f);

    // 1. Сначала вычисляем высоты
    // PrecomputeHeightfield();

    // 2. Находим мин/макс высоту для нормализации (Bullet любит, когда данные в float)
    // float minH = 99999.0f;
    // float maxH = -99999.0f;
    // for (float h : heightData) {
    //     if (h < minH) minH = h;
    //     if (h > maxH) maxH = h;
    // }

    // Если рельеф плоский, добавим немного высоты, чтобы shape не сломался
    // if (maxH - minH < 0.001f) maxH = minH + 0.1f;

    // 3. Создаем форму terrain
    // Параметры:
    // - width, length: кол-во вершин (не клеток!)
    // - data: указатель на массив float
    // - minHeight, maxHeight: диапазон высот в метрах
    // - scaleX, scaleZ: размер одной клетки в метрах (чтобы покрыть весь размер terrain)
    // - upAxis: 1 = Y (вверх)

    // float cellSizeX = TERRAIN_SIZE_X / (TERRAIN_WIDTH - 1);
    // float cellSizeZ = TERRAIN_SIZE_Z / (TERRAIN_LENGTH - 1);

    btHeightfieldTerrainShape* terrainShape = new btHeightfieldTerrainShape(TERRAIN_WIDTH,      // width (кол-во вершин по X)
                                                                            TERRAIN_LENGTH,     // length (кол-во вершин по Z)
                                                                            heightData.data(),  // указатель на массив float
                                                                            0,                  // minHeight
                                                                            0,                  // maxHeight
                                                                            1,                  // scaleX (размер одной клетки по X в метрах)
                                                                            1,                  // scaleZ (размер одной клетки по Z в метрах)
                                                                            PHY_FLOAT,          // upAxis = 1 (ось Y вверх)
                                                                            true                // useFloatData = true (мы передаём float)
    );
    terrainShape->setUseDiamondSubdivision(true);  // Опционально: улучшает качество коллизий на краях

    // 4. Создаем статический объект (масса 0)
    btTransform groundTransform;
    groundTransform.setIdentity();
    // Сдвигаем центр, если хочешь, чтобы (0,0,0) было в центре карты
    // groundTransform.setOrigin(btVector3(-TERRAIN_SIZE_X / 2, 0, -TERRAIN_SIZE_Z / 2));

    btDefaultMotionState* ms = new btDefaultMotionState(groundTransform);

    btRigidBody::btRigidBodyConstructionInfo ci(0.0f, ms, terrainShape, btVector3(0, 0, 0));
    ci.m_restitution = 0.3f;  // Немного упругости
    ci.m_friction = 0.8f;     // Трение для колес

    btRigidBody* groundBody = new btRigidBody(ci);
    world->addRigidBody(groundBody);
}

// =========================
// PHYSICS INIT
// =========================
void InitPhysics() {
    auto* config = new btDefaultCollisionConfiguration();
    auto* dispatcher = new btCollisionDispatcher(config);
    auto* broadphase = new btDbvtBroadphase();
    auto* solver = new btSequentialImpulseConstraintSolver();

    world = new btDiscreteDynamicsWorld(dispatcher, broadphase, solver, config);
    world->setGravity(btVector3(0, -9.81f, 0));

    CreateTerrain(world);

    // --- chassis ---
    auto* chassisShape = new btBoxShape(btVector3(1, 0.5, 2));

    btTransform start;
    start.setIdentity();
    start.setOrigin(btVector3(3, 5, 3));

    btScalar mass = 1500;
    btVector3 inertia(0, 0, 0);
    chassisShape->calculateLocalInertia(mass, inertia);

    btDefaultMotionState* ms = new btDefaultMotionState(start);

    btRigidBody::btRigidBodyConstructionInfo ci(mass, ms, chassisShape, inertia);
    chassisBody = new btRigidBody(ci);
    chassisBody->setActivationState(DISABLE_DEACTIVATION);
    btTransform comOffset;
    comOffset.setIdentity();
    comOffset.setOrigin(btVector3(0, 0.0f, 0.0f));

    chassisBody->setCenterOfMassTransform(chassisBody->getWorldTransform() * comOffset);
    world->addRigidBody(chassisBody);

    // --- vehicle tuning (СТАБИЛЬНОСТЬ) ---
    btRaycastVehicle::btVehicleTuning tuning;
    tuning.m_suspensionStiffness = 35.0f;
    tuning.m_suspensionDamping = 0.8f;
    tuning.m_suspensionCompression = 4.5f;
    tuning.m_frictionSlip = 0.9f;

    raycaster = new btDefaultVehicleRaycaster(world);
    vehicle = new btRaycastVehicle(tuning, chassisBody, raycaster);

    world->addVehicle(vehicle);
    vehicle->setCoordinateSystem(0, 1, 2);

    btVector3 points[4] = {btVector3(-1, 0, 2), btVector3(1, 0, 2), btVector3(-1, 0, -2), btVector3(1, 0, -2)};

    for (int i = 0; i < 4; i++) {
        vehicle->addWheel(points[i], btVector3(0, -1, 0), btVector3(-1, 0, 0), 0.2f, 0.7f, tuning, i < 2);
    }
    for (int i = 0; i < 4; i++) {
        auto& w = vehicle->getWheelInfo(i);

        if (i < 2) {
            w.m_frictionSlip = 0.9f;
            w.m_rollInfluence = 0.1f;  // перед
        } else {
            w.m_rollInfluence = 0.15f;  // зад
        }
    }
}

// // =========================
// // INPUT
// // =========================
// void UpdateInput() {
//     float engine = 0;
//     float brake = 0;
//     float steer = 0;

//     if (IsKeyDown(KEY_W)) engine = 2500;
//     if (IsKeyDown(KEY_S)) engine = -2500;

//     if (IsKeyDown(KEY_A)) steer = 0.4f;
//     if (IsKeyDown(KEY_D)) steer = -0.4f;

//     btVector3 vel = chassisBody->getLinearVelocity();
//     float speed = vel.length();

//     // float maxSteer = 0.4f * (1.0f - (speed / 30.0f, 0.0f, 0.7f));

//     static float currentSteer = 0.0f;
//     float targetSteer = steer;  // Твой расчётный steer от клавиш

//     // Плавное изменение (инерция руля)
//     // Чем меньше коэффициент (0.1), тем тяжелее руль
//     float steerRate = 0.15f;
//     currentSteer += (targetSteer - currentSteer) * steerRate;

//     vehicle->setSteeringValue(currentSteer, 0);
//     vehicle->setSteeringValue(currentSteer, 1);

//     vehicle->applyEngineForce(engine, 2);
//     vehicle->applyEngineForce(engine, 3);

//     if (IsKeyDown(KEY_SPACE)) {
//         // ручник только зад
//         vehicle->setBrake(120, 2);
//         vehicle->setBrake(120, 3);
//     } else {
//         for (int i = 0; i < 4; i++) vehicle->setBrake(0, i);
//     }
//     float speedFactor = 1.0f;

//     if (IsKeyDown(KEY_A) || IsKeyDown(KEY_D)) speedFactor = 0.7f;

//     vehicle->applyEngineForce(engine * speedFactor, 2);
//     vehicle->applyEngineForce(engine * speedFactor, 3);
// }

// =========================
// HELPERS
// =========================
Vector3 BtToRl(const btVector3& v) {
    return {v.x(), v.y(), v.z()};
}

Vector3 BtForward(const btTransform& t) {
    btVector3 f = t.getBasis().getColumn(2);
    return {f.x(), f.y(), f.z()};
}

Vector3 BtUp(const btTransform& t) {
    btVector3 u = t.getBasis().getColumn(1);
    return {u.x(), u.y(), u.z()};
}

void DrawWheel(const Vector3& pos, const btMatrix3x3& basis) {
    rlPushMatrix();

    float m[16];

    m[0] = basis[0][0];
    m[4] = basis[0][1];
    m[8] = basis[0][2];
    m[12] = pos.x + 0.15;
    m[1] = basis[1][0];
    m[5] = basis[1][1];
    m[9] = basis[1][2];
    m[13] = pos.y;
    m[2] = basis[2][0];
    m[6] = basis[2][1];
    m[10] = basis[2][2];
    m[14] = pos.z;
    m[3] = 0;
    m[7] = 0;
    m[11] = 0;
    m[15] = 1;

    rlMultMatrixf(m);

    rlRotatef(90.0f, 0, 0, 1);

    DrawCylinder({0, 0, 0}, 0.5f, 0.5f, 0.3f, 16, DARKGRAY);
    DrawCylinderWires({0, 0, 0}, 0.5f, 0.5f, 0.3f, 16, BLACK);

    rlPopMatrix();
}
// =========================
// MAIN
// =========================
int main() {
    InitWindow(1280, 720, "stable vehicle terrain");

    Camera3D cam = {0};
    cam.fovy = 60;
    cam.up = {0, 1, 0};

    InitPhysics();
    SetTargetFPS(60);
    Model chassisModel = LoadModel("assets/subaru/subaru.glb");
    Model terrainModel = GenerateTerrainModel();

    while (!WindowShouldClose()) {
        world->stepSimulation(1.f / 60.f);
        UpdateInput();

        btTransform t;
        chassisBody->getMotionState()->getWorldTransform(t);

        Vector3 pos = BtToRl(t.getOrigin());
        Vector3 forward = BtForward(t);
        Vector3 up = BtUp(t);

        float dist = 8.0f;
        float height = 3.0f;

        cam.target = pos;
        cam.position = {pos.x - forward.x * dist + up.x * height, pos.y - forward.y * dist + up.y * height, pos.z - forward.z * dist + up.z * height};

        BeginDrawing();
        ClearBackground(RAYWHITE);

        BeginMode3D(cam);

        DrawModel(terrainModel, (Vector3){-TERRAIN_LENGTH / 2, -1.1, -TERRAIN_LENGTH / 2}, 1.0f, GRAY);
        DrawTrails();
        DrawGrid(TERRAIN_LENGTH, 1);

        // 2. СТРОИМ МАТРИЦУ ТРАНСФОРМАЦИИ ВРУЧНУЮ
        // Мы берем матрицу вращения из Bullet и применяем её к модели.
        float m[16];
        const btMatrix3x3& b = t.getBasis();

        // Заполняем матрицу 4x4 (row-major для raylib)
        // Row 0
        m[0] = b[0][0];
        m[4] = b[0][1];
        m[8] = b[0][2];
        m[12] = pos.x;
        // Row 1
        m[1] = b[1][0];
        m[5] = b[1][1];
        m[9] = b[1][2];
        m[13] = pos.y;
        // Row 2
        m[2] = b[2][0];
        m[6] = b[2][1];
        m[10] = b[2][2];
        m[14] = pos.z;
        // Row 3
        m[3] = 0;
        m[7] = 0;
        m[11] = 0;
        m[15] = 1;

        // --- НАСТРОЙКА МАСШТАБА ---
        // ВАЖНО: Подбери этот коэффициент так, чтобы модель совпала с красным кубом (DrawVehicle)
        // Если модель слишком большая, ставь < 1.0. Если маленькая - > 1.0.
        // Часто для моделей из Blender в метрах подходит 1.0 или 0.5
        float modelScale = 2.5f;

        // 3. ОТРИСОВКА
        rlPushMatrix();
        rlMultMatrixf(m);  // Применяем всю матрицу (позиция + поворот + масштаб) сразу
        // Но лучше исправить это в Blender при экспорте!
        rlRotatef(180.0f, 0, 1, 0);
        DrawModel(chassisModel, (Vector3){0, 0, 0}, modelScale, WHITE);

        rlPopMatrix();

        for (int i = 0; i < vehicle->getNumWheels(); i++) {
            vehicle->updateWheelTransform(i, true);

            auto& wl = vehicle->getWheelInfo(0);
            auto& wr = vehicle->getWheelInfo(1);

            float travelL = wl.m_raycastInfo.m_suspensionLength;
            float travelR = wr.m_raycastInfo.m_suspensionLength;

            float antiRoll = (travelL - travelR) * 8000.0f;

            if (wl.m_raycastInfo.m_isInContact)
                chassisBody->applyForce(btVector3(0, -antiRoll, 0), wl.m_raycastInfo.m_contactPointWS - chassisBody->getCenterOfMassPosition());

            if (wr.m_raycastInfo.m_isInContact)
                chassisBody->applyForce(btVector3(0, antiRoll, 0), wr.m_raycastInfo.m_contactPointWS - chassisBody->getCenterOfMassPosition());

            auto tr = vehicle->getWheelInfo(i).m_worldTransform;
            btVector3 p = tr.getOrigin();

            Vector3 pos = BtToRl(p);

            trails[i].push_back({pos});

            if (trails[i].size() > MAX_TRAIL_POINTS) trails[i].erase(trails[i].begin());

            const btMatrix3x3& b = vehicle->getWheelInfo(i).m_worldTransform.getBasis();

            DrawWheel(BtToRl(tr.getOrigin()), b);
        }

        EndMode3D();
        btVector3 vel = chassisBody->getLinearVelocity();
        float speedKmh = vel.length() * 3.6f;

        DrawText("WASD + SPACE", 20, 20, 20, DARKGRAY);
        DrawText(TextFormat("SPEED  %.1f km/h", speedKmh), 40, 100, 24, BLACK);
        EndDrawing();
    }

    CloseWindow();
    return 0;
}
