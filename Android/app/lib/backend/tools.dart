import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'models.dart';

bool isBlank(String? value) => value == null || value.trim().isEmpty;

String readFileStripBom(String path) {
  final bytes = File(path).readAsBytesSync();
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    start = 3;
  }
  return utf8.decode(bytes.sublist(start), allowMalformed: true);
}

dynamic field(dynamic value, String name) {
  if (value is Map) return value[name];
  return null;
}

List<dynamic> asArray(dynamic value) => value is List ? value : const [];

List<dynamic> arrayField(dynamic value, String name) => asArray(field(value, name));

String stringField(dynamic value, String name, [String fallback = '']) {
  final result = field(value, name);
  return result == null ? fallback : result.toString();
}

int intField(dynamic value, String name, [int fallback = 0]) {
  final result = field(value, name);
  return intValue(result, fallback);
}

int intValue(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

bool boolField(dynamic value, String name, [bool fallback = false]) {
  final result = field(value, name);
  if (result == null) return fallback;
  if (result is bool) return result;
  final text = result.toString().toLowerCase();
  return text == 'true' || text == '1';
}

double floatValue(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool fileExists(String path) => !isBlank(path) && FileSystemEntity.isFileSync(path);

bool directoryExists(String path) => !isBlank(path) && FileSystemEntity.isDirectorySync(path);

void ensureDirectory(String path) {
  if (isBlank(path)) return;
  Directory(path).createSync(recursive: true);
}

void deleteDirectory(String path) {
  if (directoryExists(path)) Directory(path).deleteSync(recursive: true);
}

List<int> parseIndices(String? value) {
  if (isBlank(value)) return [];
  final out = <int>[];
  for (final part in value!.split(',')) {
    final clean = part.trim();
    if (clean.isEmpty) continue;
    final dots = clean.indexOf('..');
    if (dots != -1) {
      final a = int.tryParse(clean.substring(0, dots));
      final b = int.tryParse(clean.substring(dots + 2));
      if (a == null || b == null) continue;
      if (a <= b) {
        for (var i = a; i <= b; i++) {
          out.add(i);
        }
      } else {
        for (var i = a; i >= b; i--) {
          out.add(i);
        }
      }
      continue;
    }
    final parsed = int.tryParse(clean);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

String sanitizeName(String? value) {
  if (isBlank(value)) return 'main';
  final buffer = StringBuffer();
  var previousUnderscore = false;
  for (final rune in value!.runes) {
    final keep = (rune >= 65 && rune <= 90) ||
        (rune >= 97 && rune <= 122) ||
        (rune >= 48 && rune <= 57) ||
        rune == 46 ||
        rune == 45;
    if (keep) {
      buffer.writeCharCode(rune);
      previousUnderscore = false;
    } else if (!previousUnderscore) {
      buffer.write('_');
      previousUnderscore = true;
    }
  }
  var out = buffer.toString().trim();
  while (out.startsWith('_')) {
    out = out.substring(1);
  }
  while (out.endsWith('_')) {
    out = out.substring(0, out.length - 1);
  }
  return isBlank(out) ? 'main' : out;
}

String joinLines(Iterable<String> lines) => lines.where((line) => !isBlank(line)).join('\n');

String formatFrameIndex(int index) => index.toString().padLeft(4, '0');

int clampInt(int value, int minValue, int maxValue) {
  if (value < minValue) return minValue;
  if (value > maxValue) return maxValue;
  return value;
}

int clampChannel(double value) => clampInt(value.round(), 0, 255);

String stem(String path) => p.basenameWithoutExtension(path);

String resolveAtlasPngPath(String atlasJson, String atlasPng) {
  if (fileExists(atlasPng)) return atlasPng;
  if (!fileExists(atlasJson)) return '';
  try {
    final data = jsonDecode(readFileStripBom(atlasJson));
    var image = 'spritemap1.png';
    final atlas = field(data, 'ATLAS');
    final meta = field(atlas, 'meta') ?? field(data, 'meta');
    if (meta != null) image = stringField(meta, 'image', image);
    final dir = p.dirname(atlasJson);
    return dir == '.' ? image : p.join(dir, image);
  } catch (_) {
    return '';
  }
}

String resolveOutputDir(ProjectPaths paths, {String fallback = 'project'}) {
  if (!isBlank(paths.outputDir)) return paths.outputDir;
  var base = '';
  var anchor = '.';
  if (!isBlank(paths.animsJson)) {
    base = stem(paths.animsJson);
    anchor = paths.animsJson;
  } else if (!isBlank(paths.animsXml)) {
    base = stem(paths.animsXml);
    anchor = paths.animsXml;
  } else if (!isBlank(paths.animationJson)) {
    final dir = p.dirname(paths.animationJson);
    base = dir == '.' ? '' : p.basename(dir);
    anchor = paths.animationJson;
  } else if (!isBlank(paths.atlasPng)) {
    base = stem(paths.atlasPng);
    anchor = paths.atlasPng;
  } else if (!isBlank(paths.atlasJson)) {
    base = stem(paths.atlasJson);
    anchor = paths.atlasJson;
  }
  if (isBlank(base)) base = fallback;
  return p.join(p.dirname(anchor), 'out', sanitizeName(base));
}

RgbaImage readPng(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) throw FormatException('No pude cargar PNG: $path');
  final pixels = Uint8List(decoded.width * decoded.height * 4);
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      final offset = ((y * decoded.width) + x) << 2;
      pixels[offset] = pixel.r.toInt();
      pixels[offset + 1] = pixel.g.toInt();
      pixels[offset + 2] = pixel.b.toInt();
      pixels[offset + 3] = pixel.a.toInt();
    }
  }
  return RgbaImage(decoded.width, decoded.height, pixels);
}

void writePng(RgbaImage source, String path) {
  ensureDirectory(p.dirname(path));
  final out = img.Image(width: source.width, height: source.height, numChannels: 4);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final offset = source.pixelOffset(x, y);
      out.setPixelRgba(
        x,
        y,
        source.pixels[offset],
        source.pixels[offset + 1],
        source.pixels[offset + 2],
        source.pixels[offset + 3],
      );
    }
  }
  File(path).writeAsBytesSync(img.encodePng(out));
}

void copyPixel(RgbaImage src, int srcOffset, RgbaImage dst, int dstOffset) {
  dst.pixels[dstOffset] = src.pixels[srcOffset];
  dst.pixels[dstOffset + 1] = src.pixels[srcOffset + 1];
  dst.pixels[dstOffset + 2] = src.pixels[srcOffset + 2];
  dst.pixels[dstOffset + 3] = src.pixels[srcOffset + 3];
}

int frameNumber(String? name) {
  if (name == null) return 0;
  final base = p.basenameWithoutExtension(name);
  final match = RegExp(r'([0-9]+)$').firstMatch(base);
  return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
}

int compareNatural(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

num min4(num a, num b, num c, num d) => math.min(math.min(a, b), math.min(c, d));

num max4(num a, num b, num c, num d) => math.max(math.max(a, b), math.max(c, d));
