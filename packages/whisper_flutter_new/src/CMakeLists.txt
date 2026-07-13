# VocabKR: rebuilt for whisper.cpp v1.9.1 (upgraded from the flat 2023-era
# vintage the plugin shipped — modern ARM kernels, fixed initial_prompt,
# better decoding). whisper.cpp builds as a static subproject and links
# wholly into the libwhisper.so the Dart FFI opens.
cmake_minimum_required(VERSION 3.19)

project(whisper_flutter_library LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Static engine, linked into our shared lib.
set(BUILD_SHARED_LIBS OFF)
set(WHISPER_BUILD_EXAMPLES OFF)
set(WHISPER_BUILD_TESTS OFF)
set(WHISPER_BUILD_SERVER OFF)
set(GGML_OPENMP OFF)
# Cross-compiling for a fixed ABI set — no -march=native.
set(GGML_NATIVE OFF)

add_subdirectory(whisper.cpp)

add_library(whisper_flutter SHARED main.cpp)
set_target_properties(whisper_flutter PROPERTIES OUTPUT_NAME "whisper")
target_compile_definitions(whisper_flutter PUBLIC DART_SHARED_LIB)
target_compile_options(whisper_flutter PRIVATE -O3 -fvisibility=hidden -fvisibility-inlines-hidden -ffunction-sections -fdata-sections)
target_link_options(whisper_flutter PRIVATE -Wl,--gc-sections)
target_link_libraries(whisper_flutter PRIVATE whisper ${CMAKE_THREAD_LIBS_INIT})
