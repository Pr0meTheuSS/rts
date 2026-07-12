#include "core/Game.hpp"

int main() {
    Game game;
    game.run();
    return 0;
}

// // #include <raylib.h>

// // #include <vector>

// // #include "utilities/spline2d_generator.h"

// // int main() {
// //     const int W = 1200;
// //     const int H = 800;

// //     InitWindow(W, H, "Spline2D debug");

// //     std::vector<Spline2D::Corner> input = {
// //         Spline2D::Corner(2, Spline2D::Direction::RIGHT),
// //         Spline2D::Corner(2, Spline2D::Direction::RIGHT),
// //         Spline2D::Corner(2, Spline2D::Direction::RIGHT),
// //         Spline2D::Corner(2, Spline2D::Direction::LEFT),
// //     };

// //     auto pts = Spline2D::generateSpline2D(input, 150.0);

// //     SetTargetFPS(60);

// //     while (!WindowShouldClose()) {
// //         BeginDrawing();
// //         ClearBackground(BLACK);

// //         // оси
// //         DrawLine(W / 2, 0, W / 2, H, DARKGRAY);
// //         DrawLine(0, H / 2, W, H / 2, DARKGRAY);

// //         for (size_t i = 1; i < pts.size(); i++) {
// //             DrawLine(W / 2 + pts[i - 1].x, H / 2 + pts[i - 1].y, W / 2 + pts[i].x, H / 2 + pts[i].y, GREEN);

// //             DrawCircle(W / 2 + pts[i].x, H / 2 + pts[i].y, 4, RED);
// //         }

// //         EndDrawing();
// //     }

// //     CloseWindow();
// // }
// // #include "raylib.h"

// // //------------------------------------------------------------------------------------
// // // Program main entry point
// // //------------------------------------------------------------------------------------
// // int main(void) {
// //     // Initialization
// //     //--------------------------------------------------------------------------------------
// //     const int screenWidth = 800;
// //     const int screenHeight = 450;

// //     InitWindow(screenWidth, screenHeight, "raylib [models] example - heightmap rendering");

// //     // Define our custom camera to look into our 3d world
// //     Camera camera = {0};
// //     camera.position = (Vector3){18.0f, 21.0f, 18.0f};  // Camera position
// //     camera.target = (Vector3){0.0f, 0.0f, 0.0f};       // Camera looking at point
// //     camera.up = (Vector3){0.0f, 1.0f, 0.0f};           // Camera up vector (rotation towards target)
// //     camera.fovy = 60.0f;                               // Camera field-of-view Y
// //     camera.projection = CAMERA_PERSPECTIVE;            // Camera projection type

// //     Image image = LoadImage("heightmap.png");         // Load heightmap image (RAM)
// //     Texture2D texture = LoadTextureFromImage(image);  // Convert image to texture (VRAM)

// //     Mesh mesh = GenMeshHeightmap(image, (Vector3){16, 16, 16});  // Generate heightmap mesh (RAM and VRAM)
// //     Model model = LoadModelFromMesh(mesh);                       // Load model from generated mesh

// //     model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;  // Set map diffuse texture
// //     Vector3 mapPosition = {0.0f, 0.0f, 0.0f};                         // Define model position

// //     UnloadImage(image);  // Unload heightmap image from RAM, already uploaded to VRAM

// //     SetTargetFPS(60);  // Set our game to run at 60 frames-per-second
// //     //--------------------------------------------------------------------------------------

// //     // Main game loop
// //     while (!WindowShouldClose())  // Detect window close button or ESC key
// //     {
// //         // Update
// //         //----------------------------------------------------------------------------------
// //         UpdateCamera(&camera, CAMERA_ORBITAL);
// //         //----------------------------------------------------------------------------------

// //         // Draw
// //         //----------------------------------------------------------------------------------
// //         BeginDrawing();

// //         ClearBackground(RAYWHITE);

// //         BeginMode3D(camera);

// //         DrawModel(model, mapPosition, 1.0f, RED);

// //         DrawGrid(20, 1.0f);

// //         EndMode3D();

// //         DrawTexture(texture, screenWidth - texture.width - 20, 20, WHITE);
// //         DrawRectangleLines(screenWidth - texture.width - 20, 20, texture.width, texture.height, GREEN);

// //         DrawFPS(10, 10);

// //         EndDrawing();
// //         //----------------------------------------------------------------------------------
// //     }

// //     // De-Initialization
// //     //--------------------------------------------------------------------------------------
// //     UnloadTexture(texture);  // Unload texture
// //     UnloadModel(model);      // Unload model

// //     CloseWindow();  // Close window and OpenGL context
// //     //--------------------------------------------------------------------------------------

// //     return 0;
// // }

// // #include <stdlib.h>
// // #include <time.h>

// // #include "raylib.h"

// // int main(void) {
// //     const int screenWidth = 800;
// //     const int screenHeight = 450;

// //     InitWindow(screenWidth, screenHeight, "raylib - heightmap from noise");

// //     Camera camera = {0};
// //     camera.position = (Vector3){18.0f, 21.0f, 18.0f};
// //     camera.target = (Vector3){0.0f, 0.0f, 0.0f};
// //     camera.up = (Vector3){0.0f, 1.0f, 0.0f};
// //     camera.fovy = 60.0f;
// //     camera.projection = CAMERA_PERSPECTIVE;

// //     // Параметры карты высот
// //     const int mapSize = 128;  // должно быть степенью двойки для некоторых генераторов
// //     const float scale = 16.0f;

// //     srand((unsigned)time(NULL));

// //     // Создаём изображение-карту высот
// //     Image image = GenImageColor(mapSize, mapSize, WHITE);

// //     for (int y = 0; y < mapSize; ++y) {
// //         for (int x = 0; x < mapSize; ++x) {
// //             // Генерируем шум: случайное значение 0..255
// //             unsigned char val = (unsigned char)(rand() % 256);
// //             Color c = (Color){val, val, val, 255};
// //             unsigned char* pixelsData = static_cast<unsigned char*>(image.data);
// //             SetPixelColor(&pixelsData[x * mapSize + y], c, PIXELFORMAT_UNCOMPRESSED_GRAYSCALE);
// //         }
// //     }

// //     Texture2D texture = LoadTextureFromImage(image);
// //     Mesh mesh = GenMeshHeightmap(image, (Vector3){scale, 0.1f, scale});
// //     Model model = LoadModelFromMesh(mesh);

// //     model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;
// //     Vector3 mapPosition = {0.0f, 0.0f, 0.0f};

// //     UnloadImage(image);  // уже в VRAM как текстура

// //     SetTargetFPS(60);

// //     while (!WindowShouldClose()) {
// //         UpdateCamera(&camera, CAMERA_ORBITAL);

// //         BeginDrawing();
// //         ClearBackground(RAYWHITE);
// //         BeginMode3D(camera);
// //         DrawModel(model, mapPosition, 1.0f, RED);
// //         DrawGrid(20, 1.0f);
// //         EndMode3D();

// //         // Миниатюра карты (опционально)
// //         DrawTexture(texture, screenWidth - texture.width - 20, 20, WHITE);
// //         DrawRectangleLines(screenWidth - texture.width - 20, 20, texture.width, texture.height, GREEN);

// //         DrawFPS(10, 10);
// //         EndDrawing();
// //     }

// //     UnloadTexture(texture);
// //     UnloadModel(model);
// //     CloseWindow();

// //     return 0;
// // }

// /*******************************************************************************************
//  *
//  *   raylib [models] example - mesh generation
//  *
//  *   Example complexity rating: [★★☆☆] 2/4
//  *
//  *   Example originally created with raylib 1.8, last time updated with raylib 4.0
//  *
//  *   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
//  *   BSD-like license that allows static linking with closed source software
//  *
//  *   Copyright (c) 2017-2025 Ramon Santamaria (@raysan5)
//  *
//  ********************************************************************************************/

// // #include <cmath>

// // #include "raylib.h"
// // #define NUM_MODELS 9  // Parametric 3d shapes to generate

// // //------------------------------------------------------------------------------------
// // // Module Functions Declaration
// // //------------------------------------------------------------------------------------
// // static Mesh GenMeshCustom(void);  // Generate a simple triangle mesh from code

// // //------------------------------------------------------------------------------------
// // // Program main entry point
// // //------------------------------------------------------------------------------------
// // int main(void) {
// //     // Initialization
// //     //--------------------------------------------------------------------------------------
// //     const int screenWidth = 800;
// //     const int screenHeight = 450;

// //     InitWindow(screenWidth, screenHeight, "raylib [models] example - mesh generation");

// //     // We generate a checked image for texturing
// //     Image checked = GenImageChecked(2, 2, 1, 1, RED, GREEN);
// //     Texture2D texture = LoadTextureFromImage(checked);
// //     UnloadImage(checked);

// //     Model models[NUM_MODELS] = {0};

// //     models[0] = LoadModelFromMesh(GenMeshPlane(2, 2, 4, 3));
// //     models[1] = LoadModelFromMesh(GenMeshCube(2.0f, 1.0f, 2.0f));
// //     models[2] = LoadModelFromMesh(GenMeshSphere(2, 32, 32));
// //     models[3] = LoadModelFromMesh(GenMeshHemiSphere(2, 16, 16));
// //     models[4] = LoadModelFromMesh(GenMeshCylinder(1, 2, 16));
// //     models[5] = LoadModelFromMesh(GenMeshTorus(0.25f, 4.0f, 16, 32));
// //     models[6] = LoadModelFromMesh(GenMeshKnot(1.0f, 2.0f, 16, 128));
// //     models[7] = LoadModelFromMesh(GenMeshPoly(5, 2.0f));
// //     models[8] = LoadModelFromMesh(GenMeshCustom());

// //     // NOTE: Generated meshes could be exported using ExportMesh()

// //     // Set checked texture as default diffuse component for all models material
// //     for (int i = 0; i < NUM_MODELS; i++) models[i].materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;

// //     // Define the camera to look into our 3d world
// //     Camera camera = {{5.0f, 5.0f, 5.0f}, {0.0f, 0.0f, 0.0f}, {0.0f, 1.0f, 0.0f}, 45.0f, 0};

// //     // Model drawing position
// //     Vector3 position = {0.0f, 0.0f, 0.0f};

// //     int currentModel = 0;

// //     SetTargetFPS(60);  // Set our game to run at 60 frames-per-second
// //     //--------------------------------------------------------------------------------------

// //     // Main game loop
// //     while (!WindowShouldClose())  // Detect window close button or ESC key
// //     {
// //         // Update
// //         //----------------------------------------------------------------------------------
// //         UpdateCamera(&camera, CAMERA_ORBITAL);

// //         if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
// //             currentModel = (currentModel + 1) % NUM_MODELS;  // Cycle between the textures
// //         }

// //         if (IsKeyPressed(KEY_RIGHT)) {
// //             currentModel++;
// //             if (currentModel >= NUM_MODELS) currentModel = 0;
// //         } else if (IsKeyPressed(KEY_LEFT)) {
// //             currentModel--;
// //             if (currentModel < 0) currentModel = NUM_MODELS - 1;
// //         }
// //         //----------------------------------------------------------------------------------

// //         // Draw
// //         //----------------------------------------------------------------------------------
// //         BeginDrawing();

// //         ClearBackground(RAYWHITE);

// //         BeginMode3D(camera);

// //         DrawModel(models[currentModel], position, 1.0f, WHITE);
// //         DrawGrid(10, 1.0);

// //         EndMode3D();

// //         DrawRectangle(30, 400, 310, 30, Fade(SKYBLUE, 0.5f));
// //         DrawRectangleLines(30, 400, 310, 30, Fade(DARKBLUE, 0.5f));
// //         DrawText("MOUSE LEFT BUTTON to CYCLE PROCEDURAL MODELS", 40, 410, 10, BLUE);

// //         switch (currentModel) {
// //             case 0:
// //                 DrawText("PLANE", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 1:
// //                 DrawText("CUBE", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 2:
// //                 DrawText("SPHERE", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 3:
// //                 DrawText("HEMISPHERE", 640, 10, 20, DARKBLUE);
// //                 break;
// //             case 4:
// //                 DrawText("CYLINDER", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 5:
// //                 DrawText("TORUS", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 6:
// //                 DrawText("KNOT", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 7:
// //                 DrawText("POLY", 680, 10, 20, DARKBLUE);
// //                 break;
// //             case 8:
// //                 DrawText("Custom (triangle)", 580, 10, 20, DARKBLUE);
// //                 break;
// //             default:
// //                 break;
// //         }

// //         EndDrawing();
// //         //----------------------------------------------------------------------------------
// //     }

// //     // De-Initialization
// //     //--------------------------------------------------------------------------------------
// //     UnloadTexture(texture);  // Unload texture

// //     // Unload models data (GPU VRAM)
// //     for (int i = 0; i < NUM_MODELS; i++) UnloadModel(models[i]);

// //     CloseWindow();  // Close window and OpenGL context
// //     //--------------------------------------------------------------------------------------

// //     return 0;
// // }

// // //------------------------------------------------------------------------------------
// // // Module Functions Definition
// // //------------------------------------------------------------------------------------
// // // Generate a simple triangle mesh from code
// // // Функция ручной генерации меша террейна
// // static Mesh GenMeshCustom() {
// //     Mesh mesh = {0};
// //     int width = 20;
// //     int height = 20;
// //     float cellSize = 1;
// //     float maxHeight = 2;
// //     // Количество вершин: каждая ячейка сетки - это 2 треугольника = 6 вершин,
// //     // но вершины мы будем переиспользовать. Для простой сетки нам нужно width * height вершин.
// //     mesh.vertexCount = width * height;

// //     // Количество треугольников: (width-1)*(height-1) ячеек * 2 треугольника в ячейке
// //     int trianglesCount = (width - 1) * (height - 1) * 2;
// //     mesh.triangleCount = trianglesCount;

// //     // Выделяем память
// //     mesh.vertices = (float*)MemAlloc(mesh.vertexCount * 3 * sizeof(float));
// //     mesh.texcoords = (float*)MemAlloc(mesh.vertexCount * 2 * sizeof(float));
// //     mesh.normals = (float*)MemAlloc(mesh.vertexCount * 3 * sizeof(float));
// //     mesh.indices = (unsigned short*)MemAlloc(trianglesCount * 3 * sizeof(unsigned short));

// //     if (!mesh.vertices || !mesh.texcoords || !mesh.normals || !mesh.indices) {
// //         TraceLog(LOG_ERROR, "Не удалось выделить память для меша!");
// //         return mesh;
// //     }

// //     // 1. Заполняем вершины, UV и случайные высоты
// //     for (int z = 0; z < height; z++) {
// //         for (int x = 0; x < width; x++) {
// //             int index = z * width + x;

// //             // Позиция вершины
// //             float posX = (float)x * cellSize;
// //             float posZ = (float)z * cellSize;

// //             // Случайная высота (от 0 до maxHeight)
// //             float randomH = (float)GetRandomValue(0, 100) / 100.0f * maxHeight;
// //             float posY = randomH;

// //             mesh.vertices[index * 3 + 0] = posX;
// //             mesh.vertices[index * 3 + 1] = posY;
// //             mesh.vertices[index * 3 + 2] = posZ;

// //             // UV координаты (от 0 до 1 по всей текстуре)
// //             mesh.texcoords[index * 2 + 0] = (float)x / (width - 1);
// //             mesh.texcoords[index * 2 + 1] = (float)z / (height - 1);
// //         }
// //     }

// //     // 2. Заполняем индексы (строим треугольники)
// //     int idx = 0;
// //     for (int z = 0; z < height - 1; z++) {
// //         for (int x = 0; x < width - 1; x++) {
// //             int lt = z * width + x;              // Left Top
// //             int rt = z * width + (x + 1);        // Right Top
// //             int lb = (z + 1) * width + x;        // Left Bottom
// //             int rb = (z + 1) * width + (x + 1);  // Right Bottom

// //             // Первый треугольник (LT -> RT -> LB)
// //             mesh.indices[idx++] = (unsigned short)lt;
// //             mesh.indices[idx++] = (unsigned short)rt;
// //             mesh.indices[idx++] = (unsigned short)lb;

// //             // Второй треугольник (RT -> RB -> LB)
// //             mesh.indices[idx++] = (unsigned short)rt;
// //             mesh.indices[idx++] = (unsigned short)rb;
// //             mesh.indices[idx++] = (unsigned short)lb;
// //         }
// //     }

// //     // 3. Считаем нормали вручную
// //     // Нормаль вершины = усреднённая нормаль всех треугольников, в которых участвует эта вершина
// //     // Для простоты в этом примере мы сделаем упрощённый расчёт:
// //     // возьмём нормаль плоскости, образованной соседями (крест-накрест).
// //     for (int i = 0; i < mesh.vertexCount; i++) {
// //         float nx = 0.0f, ny = 0.0f, nz = 0.0f;
// //         int count = 0;

// //         int x = i % width;
// //         int z = i / width;

// //         // Проверяем 4 соседа (верх, низ, лево, право)
// //         int offsets[4][2] = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}};

// //         for (int k = 0; k < 4; k++) {
// //             int nxCoord = x + offsets[k][0];
// //             int nzCoord = z + offsets[k][1];

// //             if (nxCoord >= 0 && nxCoord < width && nzCoord >= 0 && nzCoord < height) {
// //                 int neighborIdx = nzCoord * width + nxCoord;

// //                 // Вектор от текущей вершины к соседу
// //                 float dx = mesh.vertices[neighborIdx * 3 + 0] - mesh.vertices[i * 3 + 0];
// //                 float dy = mesh.vertices[neighborIdx * 3 + 1] - mesh.vertices[i * 3 + 1];
// //                 float dz = mesh.vertices[neighborIdx * 3 + 2] - mesh.vertices[i * 3 + 2];

// //                 // Накопляем направление. Это упрощённая аппроксимация нормали поверхности.
// //                 // Более правильно было бы брать векторное произведение пар соседей, но этот метод даёт хороший визуальный результат для шума.
// //                 nx += dx;
// //                 ny += dy;
// //                 nz += dz;
// //                 count++;
// //             }
// //         }

// //         if (count > 0) {
// //             nx /= count;
// //             ny /= count;
// //             nz /= count;
// //         }

// //         // Нормализуем вектор
// //         float len = sqrt(nx * nx + ny * ny + nz * nz);
// //         if (len > 0.0001f) {
// //             mesh.normals[i * 3 + 0] = nx / len;
// //             mesh.normals[i * 3 + 1] = ny / len;
// //             mesh.normals[i * 3 + 2] = nz / len;
// //         } else {
// //             // Если вершина плоская (край или ошибка), ставим вверх
// //             mesh.normals[i * 3 + 0] = 0.0f;
// //             mesh.normals[i * 3 + 1] = 1.0f;
// //             mesh.normals[i * 3 + 2] = 0.0f;
// //         }
// //     }

// //     // Загружаем меш в видеопамять
// //     UploadMesh(&mesh, false);

// //     return mesh;
// // }

// #include <raylib.h>

// #include <algorithm>
// #include <cmath>
// #include <vector>

// int main() {
//     const int W = 256;
//     const int H = 256;

//     Image img = GenImageColor(W, H, BLACK);
//     unsigned char* pixels = static_cast<unsigned char*>(img.data);

//     // Параметры трассы
//     float trackWidth = 40.0f;    // ширина трассы в клетках
//     float centerRadius = 80.0f;  // радиус петли
//     float waveAmp = 2.0f;        // амплитуда волн

//     for (int y = 0; y < H; ++y) {
//         for (int x = 0; x < W; ++x) {
//             float fx = (float)x - (float)W / 2.0f;
//             float fy = (float)y - (float)H / 2.0f;

//             // Спиральная/петлевая трасса (полярная система)
//             float r = sqrt(fx * fx + fy * fy);
//             float theta = atan2(fy, fx);

//             // Делаем «волну» вдоль трассы (вдоль угла)
//             float distFromCenter = r - centerRadius;
//             float isOnTrack = 1.0f - std::clamp(std::abs(distFromCenter) / (trackWidth / 2.0f), 0.0f, 1.0f);

//             // Высота: базовая волна + рельеф трассы
//             float h = waveAmp * sinf(theta * 4.0f) * isOnTrack;
//             h += 0.5f * (1.0f - isOnTrack);  // чуть выше обочины

//             // Нормализуем в 0..1
//             h = std::clamp((h + 2.0f) / 4.0f, 0.0f, 1.0f);

//             unsigned char val = static_cast<unsigned char>(h * 255.0f);
//             Color c = {val, val, val, 255};

//             SetPixelColor(&pixels[y * W + x], c, PIXELFORMAT_UNCOMPRESSED_GRAYSCALE);
//         }
//     }

//     ExportImage(img, "rally_track_heightmap.png");
//     UnloadImage(img);
//     return 0;
// }
