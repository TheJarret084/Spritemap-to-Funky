import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'parser.dart';
import 'tools.dart' as tools;

class FunkierPacherExporter {
  Future<DescribeResult> describe(ProjectPaths paths) async {
    final logs = <String>[];
    final dataPath = _resolveDataPath(paths);
    final imagePath = paths.atlasPng;
    if (tools.isBlank(imagePath)) logs.add('Falta la imagen del spritesheet.');
    if (tools.isBlank(dataPath)) logs.add('Falta el archivo de datos del atlas.');
    if (!tools.fileExists(imagePath)) logs.add('No encontré imagen: $imagePath');
    if (!tools.fileExists(dataPath)) logs.add('No encontré atlas data: $dataPath');
    if (!tools.fileExists(dataPath)) {
      return DescribeResult(animations: const [], previewPath: imagePath, outputDir: tools.resolveOutputDir(paths, fallback: 'spritesheet'), log: tools.joinLines(logs));
    }

    try {
      final frames = _loadFrames(dataPath);
      final groups = _groupFrames(frames);
      final names = groups.keys.toList()..sort(tools.compareNatural);
      final choices = [
        for (final name in names)
          AnimDef(name, name, _buildFrameIndices(groups[name]!)),
      ];
      logs.add('Frames detectados: ${frames.length}');
      logs.add('Animaciones detectadas: ${choices.length}');
      return DescribeResult(
        animations: choices,
        previewPath: imagePath,
        outputDir: tools.resolveOutputDir(paths, fallback: 'spritesheet'),
        log: tools.joinLines(logs),
      );
    } catch (error) {
      logs.add('No pude leer el atlas data: $error');
      return DescribeResult(animations: const [], previewPath: imagePath, outputDir: tools.resolveOutputDir(paths, fallback: 'spritesheet'), log: tools.joinLines(logs));
    }
  }

  Future<ExportResult> export(ProjectPaths paths, List<AnimDef> choices) async {
    final imagePath = paths.atlasPng;
    final dataPath = _resolveDataPath(paths);
    if (!tools.fileExists(imagePath)) {
      return ExportResult(ok: false, log: 'Falta la imagen del spritesheet: $imagePath');
    }
    if (!tools.fileExists(dataPath)) {
      return ExportResult(ok: false, log: 'Falta el archivo de datos del atlas: $dataPath');
    }

    late final RgbaImage atlasImage;
    try {
      atlasImage = tools.readPng(imagePath);
    } catch (error) {
      return ExportResult(ok: false, log: 'No pude cargar la imagen: $error');
    }

    late final List<_FPFrame> frames;
    try {
      frames = _loadFrames(dataPath);
    } catch (error) {
      return ExportResult(ok: false, log: 'No pude leer el atlas data: $error');
    }

    final groups = _groupFrames(frames);
    var selected = choices.where((choice) => choice.selected && !tools.isBlank(choice.name)).map((choice) => choice.name).toList();
    if (selected.isEmpty) selected = groups.keys.toList()..sort(tools.compareNatural);
    if (selected.isEmpty) return const ExportResult(ok: false, log: 'No hay animaciones para exportar.');

    final outputDir = tools.resolveOutputDir(paths, fallback: 'spritesheet');
    tools.deleteDirectory(outputDir);
    tools.ensureDirectory(outputDir);

    var written = 0;
    for (final name in selected) {
      final group = groups[name];
      if (group == null || group.isEmpty) continue;
      group.sort(_compareFrames);
      final images = <RgbaImage>[];
      for (final frame in group) {
        final cropped = _cropFrame(atlasImage, frame.sprite);
        if (cropped != null) images.add(cropped);
      }
      if (images.isEmpty) continue;
      final strip = _buildStrip(images);
      tools.writePng(strip, p.join(outputDir, '${tools.sanitizeName(name)}.png'));
      written++;
    }

    if (written == 0) {
      return ExportResult(ok: false, log: 'No se escribió ninguna tira PNG.', outputDir: outputDir);
    }

    final zipPath = _buildZipPath(paths, imagePath);
    final logs = <String>['Tiras guardadas en: $outputDir'];
    try {
      if (File(zipPath).existsSync()) File(zipPath).deleteSync();
      ZipFileEncoder().zipDirectory(Directory(outputDir), filename: zipPath);
      logs.add('ZIP guardado en: $zipPath');
    } catch (error) {
      logs.add('Error al crear ZIP: $error');
    }

    return ExportResult(ok: true, log: tools.joinLines(logs), outputDir: outputDir, zipPath: zipPath, filesWritten: written, totalFrames: frames.length);
  }

  String _resolveDataPath(ProjectPaths paths) {
    if (!tools.isBlank(paths.animsXml)) return paths.animsXml;
    return paths.atlasJson;
  }

  List<_FPFrame> _loadFrames(String dataPath) {
    final atlas = StfParser.parseAtlas(dataPath);
    final frames = <_FPFrame>[];
    for (final entry in atlas.entries) {
      frames.add(_FPFrame(entry.key, entry.value));
    }
    frames.sort(_compareFrames);
    return frames;
  }

  Map<String, List<_FPFrame>> _groupFrames(List<_FPFrame> frames) {
    final groups = <String, List<_FPFrame>>{};
    for (final frame in frames) {
      final groupName = _detectGroupName(frame.name);
      groups.putIfAbsent(groupName, () => <_FPFrame>[]).add(frame);
    }
    return groups;
  }

  String _detectGroupName(String name) {
    if (tools.isBlank(name)) return 'animation';
    var clean = p.basenameWithoutExtension(name);
    final match = RegExp(r'^(.*?)([0-9]+)$').firstMatch(clean);
    if (match != null) {
      var base = match.group(1) ?? '';
      while (base.endsWith('_') || base.endsWith('-') || base.endsWith('.')) {
        base = base.substring(0, base.length - 1);
      }
      return tools.isBlank(base) ? 'animation' : base;
    }
    return clean;
  }

  List<int> _buildFrameIndices(List<_FPFrame> group) {
    group.sort(_compareFrames);
    return group.map((frame) => frame.frameNumber).toList();
  }

  int _compareFrames(_FPFrame a, _FPFrame b) {
    if (a.frameNumber != b.frameNumber) return a.frameNumber.compareTo(b.frameNumber);
    return tools.compareNatural(a.name, b.name);
  }

  RgbaImage? _cropFrame(RgbaImage atlas, AtlasSpriteDef sprite) {
    final drawWidth = sprite.rotated ? sprite.h : sprite.w;
    final drawHeight = sprite.rotated ? sprite.w : sprite.h;
    if (drawWidth <= 0 || drawHeight <= 0) return null;
    final out = RgbaImage(drawWidth, drawHeight);
    for (var y = 0; y < drawHeight; y++) {
      for (var x = 0; x < drawWidth; x++) {
        final sx = !sprite.rotated ? sprite.x + x : sprite.x + (sprite.w - 1 - y);
        final sy = !sprite.rotated ? sprite.y + y : sprite.y + x;
        if (sx < 0 || sy < 0 || sx >= atlas.width || sy >= atlas.height) continue;
        tools.copyPixel(atlas, atlas.pixelOffset(sx, sy), out, out.pixelOffset(x, y));
      }
    }
    return out;
  }

  RgbaImage _buildStrip(List<RgbaImage> frames) {
    var cellW = 1;
    var cellH = 1;
    for (final frame in frames) {
      if (frame.width > cellW) cellW = frame.width;
      if (frame.height > cellH) cellH = frame.height;
    }
    final strip = RgbaImage(cellW * frames.length, cellH);
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final offsetX = ((cellW - frame.width) * 0.5).floor();
      final offsetY = ((cellH - frame.height) * 0.5).floor();
      final baseX = i * cellW + offsetX;
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          tools.copyPixel(frame, frame.pixelOffset(x, y), strip, strip.pixelOffset(baseX + x, offsetY + y));
        }
      }
    }
    return strip;
  }

  String _buildZipPath(ProjectPaths paths, String imagePath) {
    final base = tools.isBlank(imagePath) ? 'spritesheet' : p.basenameWithoutExtension(imagePath);
    final parent = tools.isBlank(paths.outputDir) ? p.dirname(imagePath) : p.dirname(paths.outputDir);
    return p.join(parent, 'TJ_${tools.sanitizeName(base)}.zip');
  }
}

class _FPFrame {
  _FPFrame(this.name, this.sprite) : frameNumber = tools.frameNumber(name);

  final String name;
  final AtlasSpriteDef sprite;
  final int frameNumber;
}
