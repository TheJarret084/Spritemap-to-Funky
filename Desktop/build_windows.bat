@echo off
setlocal enabledelayedexpansion

rem Build Spritemap_to_Funky on Windows using vcpkg + CMake
rem Requirements: Visual Studio Build Tools, CMake, Git

if "%VCPKG_ROOT%"=="" (
  echo VCPKG_ROOT is not set.
  echo Example: set VCPKG_ROOT=C:\vcpkg
  exit /b 1
)

if not exist "%VCPKG_ROOT%\vcpkg.exe" (
  echo vcpkg.exe not found in %VCPKG_ROOT%
  exit /b 1
)

"%VCPKG_ROOT%\vcpkg.exe" install sdl2:x64-windows
if errorlevel 1 exit /b 1

cmake -B build -S . ^
  -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake ^
  -DVCPKG_TARGET_TRIPLET=x64-windows
if errorlevel 1 exit /b 1

cmake --build build --config Release
if errorlevel 1 exit /b 1

echo Copying SDL2.dll to build\Release
if exist "%VCPKG_ROOT%\installed\x64-windows\bin\SDL2.dll" (
  copy /Y "%VCPKG_ROOT%\installed\x64-windows\bin\SDL2.dll" "build\Release\SDL2.dll" >nul
)

echo Done.
