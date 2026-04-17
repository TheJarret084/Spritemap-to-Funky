cmake_minimum_required(VERSION 3.10)

project(backend)

set(CMAKE_CXX_STANDARD 17)

find_program(HAXELIB_EXECUTABLE haxelib)

if(NOT HAXELIB_EXECUTABLE)
    message(FATAL_ERROR "No encontré haxelib para resolver hxcpp.")
endif()

execute_process(
    COMMAND ${HAXELIB_EXECUTABLE} path hxcpp
    OUTPUT_VARIABLE HXCPP_PATHS
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

string(REGEX MATCH "([^\r\n]+)" HXCPP_ROOT "${HXCPP_PATHS}")

if(NOT HXCPP_ROOT)
    message(FATAL_ERROR "No pude resolver la ruta de hxcpp. Instala hxcpp con haxelib.")
endif()

set(SOURCES
    src/i18n.cpp
    src/parser.cpp
    src/render.cpp
    src/math.cpp
    src/utils.cpp
    src/exporter.cpp
    src/exporter_ase.cpp
    src/stb_impl.cpp
    src/api.cpp
)

add_library(backend SHARED ${SOURCES})

target_include_directories(backend PRIVATE
    include
    third_party
    ${HXCPP_ROOT}/include
)

target_compile_options(backend PRIVATE -O2 -fPIC)
