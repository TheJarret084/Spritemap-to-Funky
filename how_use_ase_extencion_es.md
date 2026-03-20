# How to Use Aseprite Extension (CLI)

Este documento explica como configurar y usar la salida `.ase` desde la app.

## Preview

![Preview 1](assets/page/ase_screenshoot.jpg)

## 1) Ruta del ejecutable (Aseprite CLI)
El campo **Aseprite CLI** debe apuntar al ejecutable real de Aseprite (modo consola).

Ejemplo en Linux:
```
/home/jarret/apps/asesprite/build/bin/aseprite
```

Verifica que exista y sea ejecutable:
```
ls -l /home/jarret/apps/asesprite/build/bin/
/home/jarret/apps/asesprite/build/bin/aseprite -v
```

Si no es ejecutable:
```
chmod +x /home/jarret/apps/asesprite/build/bin/aseprite
```

## 2) Exportar solo .ase (sin frames PNG)
Para evitar que genere los PNG por frame (lento):

1. Desmarca **Exportar frames PNG**.
2. Marca **Exportar .ase**.
3. Ejecuta **Exportar**.

Esto genera solo el `.ase` final.

## 3) Donde se guarda el .ase
El `.ase` se guarda en la carpeta de salida que elijas, con el nombre de la animacion:

```
out/<anim_name>.ase
```

## 4) Errores y logs
Si el export falla, se crea un log junto al ejecutable en:

```
logs/log_YYYYMMDD_HHMMSS.txt
```

En ese archivo veras el comando exacto que fallo, por ejemplo:
```
comando fallo (32256): "/home/jarret/apps/asesprite/build/bin/aseprite" -b --script "out/cheer/_layers/_build_ase.lua"
```

## 5) Solucion rapida a "comando fallo (32256)"
Normalmente significa que la ruta del ejecutable no existe o no es ejecutable.

Revisa el campo **Aseprite CLI** y usa la ruta real (ver seccion 1).
