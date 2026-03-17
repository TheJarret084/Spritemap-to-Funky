# Sprite Exporter

Proyecto modular para exportar frames desde `Animation.json` y `spritemap1.json` (Adobe Animate).
Incluye CLI y GUI (SDL2 + ImGui) para facilitar el flujo.

## Estructura

```
project/
├─ CMakeLists.txt
├─ src/
│  ├─ main.cpp
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
└─ third_party/
   ├─ stb/
   ├─ nlohmann/
   └─ imgui/
```

## Dependencias

Para la GUI en C++ necesitas SDL2:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libsdl2-dev
```

## Compilar con CMake

```bash
./something.sh
```

O manual:

```bash
mkdir -p build
cd build
cmake ..
make
```

Binarios finales:

```
build/Spritemap_to_Funky
```

## Compilar en Windows (MSVC + vcpkg)

1. Instala Visual Studio (o Build Tools) con C++.
2. Instala CMake y Git.
3. Instala vcpkg y SDL2:

```bat
git clone https://github.com/microsoft/vcpkg
cd vcpkg
bootstrap-vcpkg.bat
vcpkg install sdl2:x64-windows
```

4. Compila el proyecto:

```bat
cmake -B build -S . ^
  -DCMAKE_TOOLCHAIN_FILE=C:/ruta/a/vcpkg/scripts/buildsystems/vcpkg.cmake ^
  -DVCPKG_TARGET_TRIPLET=x64-windows
cmake --build build --config Release
```

Los ejecutables quedan en `build/Release/`.

Tambien puedes usar `build_windows.bat` (requiere `VCPKG_ROOT` apuntando a tu vcpkg).
  
Si al correr falla por `SDL2.dll`, copia la DLL desde:
`vcpkg/installed/x64-windows/bin/SDL2.dll` al mismo folder del `.exe`.

## Iconos (PNG en Linux / ICO en Windows)

- **Linux/macOS/Windows (icono de ventana)**: coloca `assets/icon.png`.
  El programa carga ese PNG con `SDL_SetWindowIcon`.
- **Windows (icono del .exe / taskbar)**: coloca `assets/icon.ico` y
  `assets/app.rc` (ya incluido). Esto incrusta el icono en el ejecutable.

Si no tienes PNG, el programa intenta `assets/icon.bmp` como fallback.

## Entradas esperadas

- `Animation.json`: exportado desde Adobe Animate. Contiene el timeline principal (`AN`) y los símbolos (`SD`).
- `spritemap1.json` + `spritemap1.png`: atlas con los sprites referenciados por nombre.
- `anims.xml` (opcional): define qué animaciones exportar, nombres finales e índices.
- `anims.json` (opcional, estilo FNF): lista de anims como en `bf.json`.

## Cómo se interpreta el formato

Este exporter asume el JSON de Animate con estas convenciones:

- **M3D**: se interpreta como matriz 4x4 en **column-major** (estilo `Matrix3D.rawData`):
  - `a = m[0]`, `b = m[1]`, `c = m[4]`, `d = m[5]`, `tx = m[12]`, `ty = m[13]`
  - Transformación 2D:
    - `x' = a*x + c*y + tx`
    - `y' = b*x + d*y + ty`
- **TRP** (Transform Point): actualmente **se ignora** porque en Animate
  el `M3D` ya viene con el pivote aplicado. Aplicarlo de nuevo desplaza
  piezas y rompe poses (especialmente en `singLEFT/RIGHT/DOWN`).
- **Timeline**:
  - `TL.L` son layers.
  - Cada layer contiene frames (`FR`) con `I` (inicio) y `DU` (duración).
  - En cada frame hay elementos `E`, de tipo:
    - `ASI`: sprite del atlas (usa `N` como nombre de sprite)
    - `SI`: instancia de símbolo (`SN`) con tipo `ST`
- **Looping en SI** (`LP`):
  - `LP`: loop
  - `PO`: play once (clamp al último frame)
  - `SF`: single frame (usa `FF`)
  - `FF`: first frame (0-based)

## Exportación (cómo se genera cada PNG)

Si no llenas `Salida`, se usa `out/<nombre>` (por ejemplo `out/bf`).

1. Se parsean todos los símbolos desde `SD`.
2. Se calcula el tamaño del canvas por animación usando el **bounding box** de todos sus frames.
3. Se renderiza cada frame con el mismo canvas para alinear las posiciones.
4. Se guarda como `nombre_anim_0000.png`, `nombre_anim_0001.png`, etc.

## GUI en C++ (SDL2 + ImGui)

```bash
./Spritemap_to_Funky
```

Incluye:

- Selector de archivos con navegación
- Inputs para `Animation.json`, `spritemap1.json`, `anims.xml` / `anims.json` y salida
- Campo extra para cargar `atlas PNG` manualmente
- Preview del atlas
- Selección de animaciones e índices
- Log de export
- Arrastrar y soltar archivos o carpetas en la ventana
- Icono de ventana desde `assets/icon.png` (se busca relativo al directorio actual)

## GUI simple en Python (alternativa)

```bash
python3 tools/spritemap_gui.py
```

## Limitaciones conocidas

- No soporta máscaras, blending avanzado ni filtros.
- No aplica transformaciones de color/alpha (si existieran).
- Asume que los nombres `ASI.N` existen en `spritemap1.json`.
- Si Animate exporta estructuras distintas, puede requerir ajuste en `parser.cpp`.

## Notas

- `anims.xml` es opcional, pero si se provee se usa como fuente de nombres/indices.
- Dependencias header-only en `third_party`: `stb`, `nlohmann/json`, `imgui`.


## Licencia

Este proyecto usa licencia MIT (ver `LICENSE`).
Las dependencias en `third_party/` mantienen sus licencias originales.


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
