cmake_minimum_required(VERSION 3.15)

project(wotmods_discord_rich_precense_engine VERSION 0.1)

enable_language(CXX)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory(cmake_discord_game_sdk)

find_package(pybind11 REQUIRED)
find_package(libpython REQUIRED)

add_library(engine SHARED engine.cpp)
target_link_libraries(engine PRIVATE pybind11::headers cmake_discord_game_sdk libpython::python27)
set_target_properties(cmake_discord_game_sdk
    PROPERTIES
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set_target_properties(engine
    PROPERTIES
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        SUFFIX ".pyd"
)

if (ARCH STREQUAL "x86_64")
    set(ENGINE_DESTINATION "res/mods/xfw_packages/discord_rich_presence/native_64bit/")
elseif (ARCH STREQUAL "x86")
    set(ENGINE_DESTINATION "res/mods/xfw_packages/discord_rich_presence/native_32bit/")
else ()
    message(FATAL_ERROR "not supported ARCH: ${ARCH}")
endif()

install(TARGETS engine RUNTIME DESTINATION ${ENGINE_DESTINATION})
