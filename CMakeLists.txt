cmake_minimum_required(VERSION 3.15)
project(starcraft LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)

include(${CMAKE_BINARY_DIR}/conan_toolchain.cmake)

find_package(PkgConfig REQUIRED)
find_package(spdlog REQUIRED)
find_package(raylib REQUIRED)

pkg_check_modules(MAVSDK REQUIRED mavsdk)

# Рекурсивно находим все .cpp файлы в src/
file(GLOB_RECURSE SOURCES "src/*.cpp")

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE ${MAVSDK_INCLUDE_DIRS})
target_link_libraries(${PROJECT_NAME} PRIVATE spdlog::spdlog raylib ${MAVSDK_LIBRARIES})
