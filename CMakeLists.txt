cmake_minimum_required(VERSION 3.10)

project(Spritemap_to_Funky)

set(CMAKE_CXX_STANDARD 17)

set(COMMON_SOURCES
    src/i18n.cpp
    src/parser.cpp
    src/render.cpp
    src/math.cpp
    src/utils.cpp
    src/exporter.cpp
    src/exporter_ase.cpp
    src/stb_impl.cpp
)

# GUI target (SDL2 + Dear ImGui)
if (WIN32)
    find_package(SDL2 CONFIG REQUIRED)
    set(SDL2_LIBRARIES SDL2::SDL2)
    set(SDL2_INCLUDE_DIRS "")
    set(SDL2_CFLAGS_OTHER "")
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SDL2 REQUIRED sdl2)
endif()

set(IMGUI_DIR third_party/imgui)
set(IMGUI_SOURCES
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/backends/imgui_impl_sdl2.cpp
    ${IMGUI_DIR}/backends/imgui_impl_sdlrenderer2.cpp
)

add_executable(Spritemap_to_Funky
    ${COMMON_SOURCES}
    src/gui_main.cpp
    ${IMGUI_SOURCES}
)

if (WIN32)
    if (EXISTS ${CMAKE_SOURCE_DIR}/assets/app.rc)
        target_sources(Spritemap_to_Funky PRIVATE ${CMAKE_SOURCE_DIR}/assets/app.rc)
    endif()
endif()

target_include_directories(Spritemap_to_Funky PRIVATE
    include
    third_party
    ${IMGUI_DIR}
    ${IMGUI_DIR}/backends
    ${SDL2_INCLUDE_DIRS}
)

target_compile_options(Spritemap_to_Funky PRIVATE ${SDL2_CFLAGS_OTHER})

target_link_libraries(Spritemap_to_Funky ${SDL2_LIBRARIES})

if (WIN32)
    target_compile_definitions(Spritemap_to_Funky PRIVATE SDL_MAIN_HANDLED)
endif()
