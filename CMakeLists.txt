cmake_minimum_required(VERSION 3.16)
project(als LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(ALS_WITH_RTMIDI "Valódi USB-MIDI transzport az RtMidi könyvtárral" ON)

# ---- ALS Core (statikus könyvtár: a CLI és a Flutter-DLL is ezt linkeli) ----
add_library(als_core STATIC
  core/src/midi_transport.cpp
  core/src/rtmidi_transport.cpp
  core/src/soft_registration.cpp
  core/src/wav_io.cpp
  core/src/dsp/sample_trimmer.cpp
  core/src/dsp/style_normalizer.cpp
)
target_include_directories(als_core PUBLIC core/include)
if(MSVC)
  target_compile_definitions(als_core PUBLIC _USE_MATH_DEFINES NOMINMAX)
  target_compile_options(als_core PRIVATE /utf-8 /W4)
else()
  target_compile_options(als_core PRIVATE -Wall -Wextra)
endif()

if(ALS_WITH_RTMIDI)
  include(FetchContent)
  set(RTMIDI_BUILD_TESTING OFF CACHE BOOL "" FORCE)
  set(RTMIDI_BUILD_STATIC_LIBS ON CACHE BOOL "" FORCE)
  FetchContent_Declare(rtmidi
    GIT_REPOSITORY https://github.com/thestk/rtmidi.git
    GIT_TAG 6.0.0)
  FetchContent_MakeAvailable(rtmidi)
  target_link_libraries(als_core PUBLIC rtmidi)
  target_compile_definitions(als_core PUBLIC ALS_WITH_RTMIDI)
endif()

find_package(Threads REQUIRED)
target_link_libraries(als_core PUBLIC Threads::Threads)

# ---- Parancssori program (main.cpp) ----
add_executable(als_cli app/main.cpp)
target_link_libraries(als_cli PRIVATE als_core)
if(MSVC)
  target_compile_options(als_cli PRIVATE /utf-8)
endif()

# ---- Dinamikus könyvtár a Flutter alkalmazásnak (dart:ffi) ----
#  Windows: als_core_ffi.dll · macOS: libals_core_ffi.dylib · Android: libals_core_ffi.so
add_library(als_core_ffi SHARED core/src/als_core_api.cpp)
target_link_libraries(als_core_ffi PRIVATE als_core)
set_target_properties(als_core_ffi PROPERTIES CXX_VISIBILITY_PRESET hidden)
if(WIN32)
  target_link_libraries(als_core_ffi PRIVATE comdlg32)
endif()
