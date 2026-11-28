cmake_minimum_required(VERSION 3.22)

project(ponderin_whisper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Keep the upstream engine static and private to our small exported bridge.
# We only consume the MIT-licensed whisper.cpp submodule; no GPL wrapper is
# compiled or linked into this library.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)

add_subdirectory(whisper.cpp)

find_package(Threads REQUIRED)

add_library(ponderin_whisper SHARED ponderin_whisper.cpp)
target_include_directories(ponderin_whisper PRIVATE whisper.cpp/include)
target_compile_definitions(ponderin_whisper PRIVATE DART_SHARED_LIB)
target_compile_options(ponderin_whisper PRIVATE
  -O3 -fvisibility=hidden -fvisibility-inlines-hidden
  -ffunction-sections -fdata-sections)
target_link_options(ponderin_whisper PRIVATE -Wl,--gc-sections)
target_link_libraries(ponderin_whisper PRIVATE whisper Threads::Threads)
