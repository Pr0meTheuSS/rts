#include "raylib.h"

int main() {
    // создаём окно
    InitWindow(800, 450, "Hello Raylib!");
    SetTargetFPS(60);

    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(RAYWHITE);

        DrawText("Hello, world!", 350, 200, 20, DARKBLUE);

        EndDrawing();
    }

    CloseWindow();
    return 0;
}
