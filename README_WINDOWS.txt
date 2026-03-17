Spritemap to Funky - Windows build quick steps

1) Install Visual Studio (or Build Tools) with C++
2) Install CMake and Git
3) Install vcpkg:
   git clone https://github.com/microsoft/vcpkg
   cd vcpkg
   bootstrap-vcpkg.bat

4) Set VCPKG_ROOT and build:
   set VCPKG_ROOT=C:\\path\\to\\vcpkg
   cd <project folder>
   build_windows.bat

Output:
  build\Release\Spritemap_to_Funky.exe
If SDL2.dll is missing, the script copies it automatically.
