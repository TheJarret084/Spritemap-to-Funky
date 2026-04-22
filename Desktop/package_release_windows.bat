@echo off
setlocal

set ROOT=%~dp0
cd /d %ROOT%

set BIN=build\Release\Spritemap_to_Funky.exe
if not exist "%BIN%" (
  echo Binary not found: %BIN%
  echo Run build_windows.bat first.
  exit /b 1
)

set OUT_DIR=dist\Spritemap_to_Funky-windows-x64
if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

copy /Y "%BIN%" "%OUT_DIR%\Spritemap_to_Funky.exe" >nul
if exist "build\Release\SDL2.dll" copy /Y "build\Release\SDL2.dll" "%OUT_DIR%\SDL2.dll" >nul
xcopy /E /I /Y assets "%OUT_DIR%\assets" >nul
copy /Y README.md "%OUT_DIR%\README.md" >nul
copy /Y LICENSE "%OUT_DIR%\LICENSE" >nul

set ZIP=dist\Spritemap_to_Funky-windows-x64.zip
if exist "%ZIP%" del /f /q "%ZIP%"

powershell -Command "Compress-Archive -Path '%OUT_DIR%\*' -DestinationPath '%ZIP%'"

echo Release package created: %ZIP%
endlocal
