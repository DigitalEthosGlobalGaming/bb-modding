cmake_minimum_required(VERSION 3.16)
project(bbmod C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(BBMOD_WITH_ZYDIS "Build inline hooks with Zydis" ON)
option(BBMOD_BUILD_TESTS "Build the test harness and tests" ON)

add_library(bbmod_host STATIC
    host/src/modhost.c
    host/src/host.c
    host/src/loader.c
    host/src/code.c
    host/src/xmlpatch.c
    host/src/manifest.c
    host/src/vfs.c
    host/src/net.c
    host/src/gameplay.c
    host/src/equipment.c
    host/src/characters.c
    host/src/characters_service.c
    host/src/inventory.c
    host/src/inventory_service.c
    host/src/equipment_service.c
    host/src/item_actions.c
    host/src/native_attack.c
    host/src/native_observation.c
    host/src/ui_tables.c
    host/src/ui_slots.c
    host/src/native_menu.c
    host/src/native_menu_bridge.c
    host/src/pad.c
    host/src/platform_posix.c
    host/src/platform_win.c
)
target_include_directories(bbmod_host PUBLIC host/include sdk/include)
if(NOT WIN32)
    target_link_libraries(bbmod_host PUBLIC dl pthread)
endif()

if(BBMOD_WITH_ZYDIS)
    find_package(Zydis QUIET)
    if(Zydis_FOUND)
        target_compile_definitions(bbmod_host PRIVATE BBM_WITH_ZYDIS=1)
        target_link_libraries(bbmod_host PUBLIC Zydis::Zydis)
    else()
        message(FATAL_ERROR "Zydis requested but not found. Install Zydis or explicitly set BBMOD_WITH_ZYDIS=OFF for a reduced build.")
    endif()
endif()

if(BBMOD_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
