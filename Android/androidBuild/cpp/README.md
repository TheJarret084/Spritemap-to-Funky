# Spritemap to Funky

Tool para exportar frames desde `Animation.json` y `spritemap1.json` (Adobe Animate), con GUI.

## Estructura

```
project/
├─ CMakeLists.txt
├─ src/
│  ├─ gui_main.cpp
│  ├─ exporter.cpp
│  ├─ parser.cpp
│  ├─ render.cpp
│  ├─ math.cpp
│  ├─ utils.cpp
│  └─ stb_impl.cpp
├─ include/
│  ├─ exporter.hpp
│  ├─ parser.hpp
│  ├─ render.hpp
│  ├─ math.hpp
│  ├─ utils.hpp
│  └─ types.hpp
├─ tools/
│  └─ spritemap_gui.py
├─ assets/
│  ├─ icon.png
│  ├─ icon.ico
│  └─ app.rc
├─ build_Unix.sh
├─ build_windows.bat
├─ package_release.sh
├─ package_release_windows.bat
└─ README_WINDOWS.txt
```

## Dependencias

Para la GUI en C++ necesitas SDL2:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libsdl2-dev
```

## Compilar en Linux

```bash
./build_Unix.sh
```

Binario final:

```
build/Spritemap_to_Funky
```

## Compilar en Windows (MSVC + vcpkg)

Ver `README_WINDOWS.txt` para pasos rápidos.

Resumen:

```bat
set VCPKG_ROOT=C:
utacpkg
build_windows.bat
```

Ejecutable:

```
build\Release\Spritemap_to_Funky.exe
```

## Iconos (PNG en Linux / ICO en Windows)

- **Linux/macOS/Windows (icono de ventana)**: `assets/icon.png`
- **Windows (icono del .exe / taskbar)**: `assets/icon.ico` + `assets/app.rc`

## Entradas esperadas

- `Animation.json`: timeline principal (`AN`) y símbolos (`SD`).
- `spritemap1.json` + `spritemap1.png`: atlas con los sprites.
- `anims.xml` (opcional, **codename**): define nombres/indices.
- `anims.json` (opcional, **psych/bf**): lista de animaciones estilo FNF.

## Uso (GUI)

```bash
./Spritemap_to_Funky
```

Incluye:

- Selector de archivos con navegación
- Inputs para `Animation.json`, `spritemap1.json`, `anims.xml` / `anims.json`
- Campo extra para cargar `atlas PNG` manualmente
- Preview del atlas
- Selección de animaciones e índices
- Log de export
- Arrastrar y soltar archivos o carpetas en la ventana
- Barra de progreso al exportar
- Exportar `.ase` con Aseprite (opcional)

## Exportar .ase (Aseprite)

- Marca **Exportar .ase** y pon la ruta del ejecutable (`aseprite`) si no está en el PATH.
- Se genera un archivo por animación dentro de la carpeta de salida: `out/<personaje>/<anim>.ase`.
- Los frames combinados siguen saliendo en su carpeta (`out/<nombre>/<nombre>_0000.png`, etc.).
- Para capas, se generan PNGs por pieza en `out/<nombre>/_layers/<layer>/<layer>_0000.png`.

## Exportación (cómo se genera cada PNG)

Si no llenas `Salida`, se usa `out/<nombre>` (por ejemplo `out/bf`).

1. Se parsean todos los símbolos desde `SD`.
2. Se calcula el tamaño del canvas por animación usando el **bounding box** de todos sus frames.
3. Se renderiza cada frame con el mismo canvas para alinear las posiciones.
4. Se guarda como `nombre_anim_0000.png`, `nombre_anim_0001.png`, etc.

## Formato (Animate)

- **M3D**: matriz 4x4 **column-major** (`Matrix3D.rawData`)
  - `a = m[0]`, `b = m[1]`, `c = m[4]`, `d = m[5]`, `tx = m[12]`, `ty = m[13]`
  - `x' = a*x + c*y + tx`
  - `y' = b*x + d*y + ty`
- **TRP**: se ignora porque `M3D` ya viene con el pivote aplicado.
- **LP**: `LP` loop, `PO` play once, `SF` single frame, `FF` first frame.

## Releases (paquetes listos para GitHub)

Linux:

```bash
./build_Unix.sh
./package_release.sh
```

Salida: `dist/Spritemap_to_Funky-linux-x64.tar.gz`

Windows (CMD):

```bat
build_windows.bat
package_release_windows.bat
```

Salida: `dist\Spritemap_to_Funky-windows-x64.zip`

## Licencia

MIT. Ver `LICENSE`. Las dependencias en `third_party/` mantienen sus licencias originales.
