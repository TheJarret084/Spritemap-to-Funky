import 'dart:convert';
import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'models.dart';
import 'tools.dart' as tools;

class StfParser {
  static List<AnimDef> parseAnimXml(String path) {
    final out = <AnimDef>[];
    final document = XmlDocument.parse(tools.readFileStripBom(path));
    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local != 'anim') continue;
      final name = node.getAttribute('name');
      final source = node.getAttribute('anim');
      if (!tools.isBlank(name) && !tools.isBlank(source)) {
        out.add(AnimDef(name!, source!, tools.parseIndices(node.getAttribute('indices'))));
      }
    }
    return out;
  }

  static Map<String, AtlasSpriteDef> parseAtlas(String path) {
    final text = tools.readFileStripBom(path).trim();
    if (text.startsWith('<')) return _parseXmlAtlas(text);
    final data = jsonDecode(text);
    return parseAtlasData(data);
  }

  static Map<String, AtlasSpriteDef> parseAtlasData(dynamic data) {
    final atlas = <String, AtlasSpriteDef>{};

    final atlasRoot = tools.field(data, 'ATLAS');
    for (final entry in tools.arrayField(atlasRoot, 'SPRITES')) {
      final spriteJson = tools.field(entry, 'SPRITE');
      if (spriteJson == null) continue;
      final name = tools.stringField(spriteJson, 'name');
      if (tools.isBlank(name)) continue;
      atlas[name] = AtlasSpriteDef(
        x: tools.intField(spriteJson, 'x'),
        y: tools.intField(spriteJson, 'y'),
        w: tools.intField(spriteJson, 'w'),
        h: tools.intField(spriteJson, 'h'),
        rotated: tools.boolField(spriteJson, 'rotated'),
      );
    }
    if (atlas.isNotEmpty) return atlas;

    final frames = tools.field(data, 'frames');
    if (frames is Map) {
      for (final entry in frames.entries) {
        final value = entry.value;
        final frame = tools.field(value, 'frame') ?? value;
        atlas[entry.key.toString()] = AtlasSpriteDef(
          x: tools.intField(frame, 'x'),
          y: tools.intField(frame, 'y'),
          w: tools.intField(frame, 'w'),
          h: tools.intField(frame, 'h'),
          rotated: tools.boolField(value, 'rotated'),
        );
      }
    } else if (frames is List) {
      for (final value in frames) {
        final name = tools.stringField(value, 'filename', tools.stringField(value, 'name'));
        if (tools.isBlank(name)) continue;
        final frame = tools.field(value, 'frame') ?? value;
        atlas[name] = AtlasSpriteDef(
          x: tools.intField(frame, 'x'),
          y: tools.intField(frame, 'y'),
          w: tools.intField(frame, 'w'),
          h: tools.intField(frame, 'h'),
          rotated: tools.boolField(value, 'rotated'),
        );
      }
    }
    if (atlas.isNotEmpty) return atlas;

    for (final value in tools.arrayField(data, 'sprites')) {
      final name = tools.stringField(value, 'name');
      if (tools.isBlank(name)) continue;
      atlas[name] = AtlasSpriteDef(
        x: tools.intField(value, 'x'),
        y: tools.intField(value, 'y'),
        w: tools.intField(value, 'w', tools.intField(value, 'width')),
        h: tools.intField(value, 'h', tools.intField(value, 'height')),
        rotated: tools.boolField(value, 'rotated'),
      );
    }

    return atlas;
  }

  static Map<String, AtlasSpriteDef> _parseXmlAtlas(String text) {
    final atlas = <String, AtlasSpriteDef>{};
    final document = XmlDocument.parse(text);
    for (final node in document.descendants.whereType<XmlElement>()) {
      final tag = node.name.local.toLowerCase();
      if (tag != 'subtexture' && tag != 'sprite') continue;
      final name = node.getAttribute('name') ?? node.getAttribute('n');
      if (tools.isBlank(name)) continue;
      atlas[name!] = AtlasSpriteDef(
        x: _xmlInt(node, 'x'),
        y: _xmlInt(node, 'y'),
        w: _xmlInt(node, 'w', _xmlInt(node, 'width')),
        h: _xmlInt(node, 'h', _xmlInt(node, 'height')),
        rotated: _xmlBool(node, 'rotated') || _xmlBool(node, 'rotate'),
      );
    }
    return atlas;
  }

  static int _xmlInt(XmlElement node, String name, [int fallback = 0]) {
    return int.tryParse(node.getAttribute(name) ?? '') ?? fallback;
  }

  static bool _xmlBool(XmlElement node, String name) {
    final value = node.getAttribute(name)?.toLowerCase();
    return value == 'true' || value == '1';
  }

  static Transform parseM3d(dynamic raw) {
    final transform = Transform();
    if (raw != null && raw is! List) {
      transform.a = tools.floatValue(tools.field(raw, 'm00'), 1);
      transform.b = tools.floatValue(tools.field(raw, 'm01'));
      transform.c = tools.floatValue(tools.field(raw, 'm10'));
      transform.d = tools.floatValue(tools.field(raw, 'm11'), 1);
      transform.tx = tools.floatValue(tools.field(raw, 'm30'));
      transform.ty = tools.floatValue(tools.field(raw, 'm31'));
      return transform;
    }

    final values = tools.asArray(raw);
    if (values.length < 16) return transform;
    transform.a = tools.floatValue(values[0], 1);
    transform.b = tools.floatValue(values[1]);
    transform.c = tools.floatValue(values[4]);
    transform.d = tools.floatValue(values[5], 1);
    transform.tx = tools.floatValue(values[12]);
    transform.ty = tools.floatValue(values[13]);
    return transform;
  }

  static Transform parseMx(dynamic raw) {
    final transform = Transform();
    final values = tools.asArray(raw);
    if (values.length < 6) return transform;
    transform.a = tools.floatValue(values[0], 1);
    transform.b = tools.floatValue(values[1]);
    transform.c = tools.floatValue(values[2]);
    transform.d = tools.floatValue(values[3], 1);
    transform.tx = tools.floatValue(values[4]);
    transform.ty = tools.floatValue(values[5]);
    return transform;
  }

  static TimelineData parseTimeline(dynamic raw) {
    final timeline = TimelineData();
    final compactLayers = tools.arrayField(raw, 'L');
    if (compactLayers.isNotEmpty) {
      _parseCompactLayers(compactLayers, timeline);
    } else {
      _parseVerboseLayers(tools.arrayField(raw, 'LAYERS'), timeline);
    }

    var maxEnd = 0;
    for (final layer in timeline.layers) {
      for (final frame in layer.frames) {
        final frameEnd = frame.start + frame.duration;
        if (frameEnd > maxEnd) maxEnd = frameEnd;
      }
    }
    timeline.totalFrames = maxEnd;
    return timeline;
  }

  static Transform _parseCompactTransform(dynamic raw) {
    final mx = tools.field(raw, 'MX');
    if (mx != null) return parseMx(mx);
    return parseM3d(tools.field(raw, 'M3D'));
  }

  static void _parseCompactLayers(List<dynamic> layers, TimelineData timeline) {
    for (final layerJson in layers) {
      final layer = TimelineLayer();
      for (final frameJson in tools.arrayField(layerJson, 'FR')) {
        final frame = TimelineFrame()
          ..start = tools.intField(frameJson, 'I')
          ..duration = tools.intField(frameJson, 'DU', 1);

        for (final elementJson in tools.arrayField(frameJson, 'E')) {
          final atlasSprite = tools.field(elementJson, 'ASI');
          if (atlasSprite != null) {
            final element = TimelineElement(ElementType.atlasSprite)
              ..name = tools.stringField(atlasSprite, 'N')
              ..transform = _parseCompactTransform(atlasSprite);
            frame.elements.add(element);
            continue;
          }

          final symbolInstance = tools.field(elementJson, 'SI');
          if (symbolInstance != null) {
            final element = TimelineElement(ElementType.symbolInstance)
              ..name = tools.stringField(symbolInstance, 'SN')
              ..firstFrame = tools.intField(symbolInstance, 'FF')
              ..symbolType = tools.stringField(symbolInstance, 'ST')
              ..loop = tools.stringField(symbolInstance, 'LP')
              ..transform = _parseCompactTransform(symbolInstance);
            frame.elements.add(element);
          }
        }
        layer.frames.add(frame);
      }
      timeline.layers.add(layer);
    }
  }

  static void _parseVerboseLayers(List<dynamic> layers, TimelineData timeline) {
    for (final layerJson in layers) {
      final layer = TimelineLayer();
      for (final frameJson in tools.arrayField(layerJson, 'Frames')) {
        final frame = TimelineFrame()
          ..start = tools.intField(frameJson, 'index')
          ..duration = tools.intField(frameJson, 'duration', 1);

        for (final elementJson in tools.arrayField(frameJson, 'elements')) {
          final atlasSprite = tools.field(elementJson, 'ATLAS_SPRITE_instance');
          if (atlasSprite != null) {
            final element = TimelineElement(ElementType.atlasSprite)
              ..name = tools.stringField(atlasSprite, 'name')
              ..transform = parseM3d(tools.field(atlasSprite, 'Matrix3D'));
            _applyDecomposedFallback(element.transform, tools.field(atlasSprite, 'DecomposedMatrix'));
            frame.elements.add(element);
            continue;
          }

          final symbolInstance = tools.field(elementJson, 'SYMBOL_Instance');
          if (symbolInstance != null) {
            final element = TimelineElement(ElementType.symbolInstance)
              ..name = tools.stringField(symbolInstance, 'SYMBOL_name')
              ..firstFrame = tools.intField(symbolInstance, 'firstFrame')
              ..symbolType = tools.stringField(symbolInstance, 'symbolType')
              ..loop = tools.stringField(symbolInstance, 'loop')
              ..transform = parseM3d(tools.field(symbolInstance, 'Matrix3D'));
            if (tools.isBlank(element.loop) && element.symbolType.trim().toLowerCase() == 'movieclip') {
              element.loop = 'singleframe';
            }
            _applyDecomposedFallback(element.transform, tools.field(symbolInstance, 'DecomposedMatrix'));
            frame.elements.add(element);
          }
        }
        layer.frames.add(frame);
      }
      timeline.layers.add(layer);
    }
  }

  static void _applyDecomposedFallback(Transform transform, dynamic decomposed) {
    if (decomposed == null) return;
    final rotation = tools.field(decomposed, 'Rotation');
    final rx = tools.floatValue(tools.field(rotation, 'x'));
    final ry = tools.floatValue(tools.field(rotation, 'y'));
    final rz = tools.floatValue(tools.field(rotation, 'z'));
    final noRotation = rx.abs() < 1e-6 && ry.abs() < 1e-6 && rz.abs() < 1e-6;
    if (!noRotation || (transform.b.abs() <= 1e-6 && transform.c.abs() <= 1e-6)) return;

    final scaling = tools.field(decomposed, 'Scaling');
    final position = tools.field(decomposed, 'Position');
    final sx = tools.floatValue(tools.field(scaling, 'x'), 1);
    final sy = tools.floatValue(tools.field(scaling, 'y'), 1);
    final px = tools.floatValue(tools.field(position, 'x'));
    final py = tools.floatValue(tools.field(position, 'y'));
    final cr = math.cos(rz);
    final sr = math.sin(rz);

    transform
      ..a = cr * sx
      ..b = sr * sx
      ..c = -sr * sy
      ..d = cr * sy
      ..tx = px
      ..ty = py;
  }
}
