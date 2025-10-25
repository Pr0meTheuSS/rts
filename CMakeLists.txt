cmake_minimum_required(VERSION 3.31)
project(starcraft LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)

include(${CMAKE_BINARY_DIR}/conan_toolchain.cmake)

find_package(PkgConfig REQUIRED)
find_package(spdlog REQUIRED)
find_package(raylib REQUIRED)

# Рекурсивно находим все .cpp файлы в src/
file(GLOB_RECURSE SOURCES "src/*.cpp")

add_executable(${PROJECT_NAME} ${SOURCES})

target_link_libraries(${PROJECT_NAME} PRIVATE spdlog::spdlog raylib)
