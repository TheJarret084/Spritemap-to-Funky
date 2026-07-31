# Spritemap to Funky Flutter

Esta carpeta ya contiene la reescritura Flutter/Dart:

- `lib/main.dart`: UI Flutter con tabs para Spritemap y Funkier.
- `lib/backend/`: parser, renderer, cropper y exportadores ZIP en Dart.
- `pubspec.yaml`: dependencias, assets y fuentes.
- `android/`: estructura Android mínima para Flutter.

Para compilar en una máquina con Flutter:

```bash
flutter pub get
flutter run
```

Si Gradle pide `android/local.properties`, créalo con la ruta de tu SDK Flutter:

```properties
flutter.sdk=/ruta/a/flutter
```

echo 'export PATH="</home/jarret/apps/flutter/flutter/bin/>:$PATH"' >> ~/.bash_profile


No pude ejecutar `flutter analyze` ni `flutter build` aquí porque esta máquina no tiene `flutter` ni `dart` instalados.
