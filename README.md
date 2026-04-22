# Spritemap to Funky

Herramienta para convertir exportaciones de spritemap/timeline en assets listos para workflows tipo Friday Night Funkin'. El repo incluye:

- Una app de escritorio en C++ con SDL2 + Dear ImGui.
- Una edición Android en Haxe/OpenFL.
- Exportación de frames PNG por animación.
- Exportación opcional a `.ase` usando Aseprite CLI.

Licencia: MIT.

## Qué hace

La app toma como base archivos exportados desde un flujo de spritemap:

- `Animation.json`
- `spritemap1.json`
- `spritemap1.png`

Opcionalmente también puede consumir:

- `anims.xml` para listas estilo Codename Engine.
- `anims.json` para listas estilo Psych/FNF.

Con eso:

- Detecta símbolos y animaciones.
- Permite elegir cuáles exportar.
- Renderiza cada frame recortado a su canvas real.
- Guarda una carpeta por animación.
- Puede generar un `.ase` final por animación si Aseprite CLI está disponible.

## Formatos de entrada

### Requeridos

- `Animation.json`: timeline principal y símbolos.
- `spritemap1.json`: atlas con coordenadas y metadatos.
- `spritemap1.png`: atlas de imágenes.

### Opcionales

- `anims.xml`: define nombres visibles y `indices`.
- `anims.json`: alternativa para listas de animación estilo Psych.
- Atlas PNG manual: si no se elige explícitamente, la app intenta resolverlo desde `spritemap1.json`.

## Salida generada

La exportación crea una carpeta de salida con una subcarpeta por animación:

```text
out/
  idle/
    idle_0000.png
    idle_0001.png
  singLEFT/
    singLEFT_0000.png
```

Si se activa la salida `.ase`, también genera:

```text
out/
  idle.ase
  singLEFT.ase
```

Durante la exportación `.ase`, la app arma capas temporales en `_layers/` y luego invoca Aseprite por CLI para construir el archivo final.

## App de escritorio

La versión principal vive en [`Desktop/`](./Desktop).

### Funciones principales

- Interfaz visual con preview del atlas.
- Carga manual de `Animation.json`, `spritemap1.json`, PNG, `anims.xml` y `anims.json`.
- Detección automática de animaciones desde:
  - `anims.json`
  - `anims.xml`
  - o directamente desde `Animation.json`
- Filtro y selección de animaciones.
- Exportación de PNG por frame.
- Exportación de `.ase`.
- Soporte de idioma desde XML:
  - [`Desktop/assets/lang/es.xml`](./Desktop/assets/lang/es.xml)
  - [`Desktop/assets/lang/en.xml`](./Desktop/assets/lang/en.xml)

### Build en Linux/Unix

Requisitos:

- `cmake`
- compilador con C++17
- `pkg-config`
- `SDL2`

Script incluido:

```bash
cd Desktop
./build_Unix.sh
```

Ese script hace:

```bash
cmake ..
make -j"$(nproc)"
```

El binario queda en `Desktop/build/`.

### Build en Windows

Requisitos:

- Visual Studio Build Tools
- CMake
- Git
- `vcpkg`

Variable requerida:

```bat
set VCPKG_ROOT=C:\vcpkg
```

Luego:

```bat
cd Desktop
build_windows.bat
```

El script instala `sdl2:x64-windows`, compila en `Release` y copia `SDL2.dll` a la carpeta de salida.

### Uso rápido

1. Abre la app.
2. Carga `Animation.json`.
3. Carga `spritemap1.json`.
4. Opcionalmente carga el PNG del atlas para preview.
5. Opcionalmente carga `anims.xml` o `anims.json`.
6. Elige carpeta de salida.
7. Marca si quieres:
   - `Exportar frames PNG`
   - `Exportar .ase`
8. Si exportas `.ase`, indica la ruta del ejecutable de Aseprite.
9. Presiona `Exportar`.

La UI también puede reconstruir la lista de animaciones automáticamente según el archivo auxiliar disponible.

### Exportación `.ase`

La salida `.ase` depende de Aseprite en modo CLI.

Ejemplo de ruta en Linux:

```bash
/ruta/a/aseprite
```

Puedes verificarlo con:

```bash
aseprite -v
```

Notas:

- Si solo quieres `.ase`, puedes desactivar `Exportar frames PNG`.
- Si Aseprite falla, la app guarda un log en `logs/log_YYYYMMDD_HHMMSS.txt` junto al ejecutable.
- El error `comando fallo (32256)` normalmente apunta a ruta incorrecta o ejecutable sin permisos.

Documentación previa relacionada:

- [`Desktop/how_use_ase_extencion_es.md`](./Desktop/how_use_ase_extencion_es.md)
- [`Desktop/how_use_ase_extencion_en.md`](./Desktop/how_use_ase_extencion_en.md)

### Modo CLI mínimo

Existe un `main.cpp` con uso directo de exportación:

```bash
spritemap_export Animation.json spritemap1.json [out_dir] [anims.xml]
```

Esto permite lanzar exportaciones sin abrir la GUI, aunque el target principal del proyecto actual es la app visual.

## App Android

La edición Android vive en [`Android/androidBuild/`](./Android/androidBuild).

Está hecha con:

- Haxe
- OpenFL
- Lime

### Qué hace en Android

- Permite seleccionar archivos del proyecto desde el dispositivo.
- Copia los archivos necesarios al almacenamiento interno.
- Detecta animaciones igual que la versión desktop.
- Exporta frames PNG.
- Empaqueta la salida en un `.zip`.
- Abre un selector para decidir dónde guardar ese ZIP.

La edición Android está orientada a exportación portátil. En el código actual no aparece flujo de exportación `.ase` dentro de esta variante.

### Requisitos de build

- Haxe
- `haxelib`
- `lime`
- `openfl`
- Android SDK
- Android NDK
- Java 17

Archivo principal del proyecto:

- [`Android/androidBuild/app/project.xml`](./Android/androidBuild/app/project.xml)

### Setup Android en desktop Linux

Script incluido:

```bash
cd Android/androidBuild/app/build
./android-setup.sh
```

Ese script prepara:

- `JAVA_HOME`
- `ANDROID_HOME`
- `ANDROID_SDK_ROOT`
- `ANDROID_NDK_ROOT`
- command line tools de Android
- plataformas y build-tools
- config de Lime

Usa por defecto:

- Android platform `33`
- Build Tools `33.0.2`
- NDK `25.2.9519653`

### Setup Android en Termux

Script incluido:

```bash
cd Android/androidBuild/app/build
./android-setup-termux.sh
```

Instala paquetes base, descarga command-line tools y deja listo el entorno para compilar desde Termux.

### Compilar APKs

Desde [`Android/androidBuild/`](./Android/androidBuild):

```bash
./build.sh
```

Opciones:

```bash
./build.sh all
./build.sh normal
./build.sh caros
```

Salidas esperadas:

- `dist/SpritemaptoFunky-normal.apk`
- `dist/SpritemaptoFunky-debug-caros-edition.apk`

## Estructura del repositorio

```text
Desktop/
  CMakeLists.txt
  src/
  include/
  assets/
  third_party/
  source_test/

Android/
  androidBuild/
    app/
    build.sh

LICENSE
README.md
```

### Carpetas importantes

- `Desktop/src/`: lógica principal, GUI, parser y exportadores.
- `Desktop/include/`: headers del core.
- `Desktop/assets/`: iconos, idiomas, media y recursos de la app.
- `Desktop/third_party/`: Dear ImGui, stb y nlohmann/json.
- `Desktop/source_test/`: ejemplos de entrada y datos de prueba.
- `Android/androidBuild/app/src/`: UI y backend Android.

## Dependencias embebidas

El proyecto ya incluye en el repo:

- Dear ImGui
- stb
- nlohmann/json

La dependencia externa más importante para desktop es SDL2.

## Flujo recomendado de uso

1. Exporta desde tu herramienta origen los archivos `Animation.json`, `spritemap1.json` y `spritemap1.png`.
2. Abre la app desktop.
3. Carga los archivos base.
4. Si ya tienes una lista de animaciones del mod, carga `anims.xml` o `anims.json`.
5. Revisa el preview del atlas para confirmar que todo resolvió bien.
6. Exporta PNGs y, si quieres edición por capas, genera también `.ase`.

## Notas y limitaciones actuales

- El parser soporta más de un formato de timeline JSON, pero el foco real del proyecto sigue siendo el flujo de spritemap usado por la app.
- La salida `.ase` requiere Aseprite instalado localmente y accesible por CLI.
- La documentación original del repo estaba dispersa y parcialmente incompleta; este README centraliza el estado actual del código.
- Hay archivos de notas antiguas en Android que no reflejan necesariamente el estado real del build.

## Recursos visuales y página de descargas

En la [`pagina principal`](./index.html) hay un portal de descargas con links de release, video tutorial y material visual del proyecto.

## Créditos

Proyecto mantenido en este repo por mi persona:  `TheJarret084`.

La página de descargas incluida en el repo menciona que está basada en una versión previa de `Spritemap to Funky` creada por `Unwifoxy`.

Nota: [oye foxy el icono de la app para cuando?]
