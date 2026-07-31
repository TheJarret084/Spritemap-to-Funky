import 'models.dart';
import 'tools.dart' as tools;

class Renderer {
  static Transform multiply(Transform parent, Transform local) {
    return Transform(
      a: parent.a * local.a + parent.c * local.b,
      b: parent.b * local.a + parent.d * local.b,
      c: parent.a * local.c + parent.c * local.d,
      d: parent.b * local.c + parent.d * local.d,
      tx: parent.a * local.tx + parent.c * local.ty + parent.tx,
      ty: parent.b * local.tx + parent.d * local.ty + parent.ty,
    );
  }

  static Transform? invert(Transform transform) {
    final det = transform.a * transform.d - transform.b * transform.c;
    if (det.abs() < 1e-10) return null;
    final invDet = 1 / det;
    return Transform(
      a: transform.d * invDet,
      b: -transform.b * invDet,
      c: -transform.c * invDet,
      d: transform.a * invDet,
      tx: (transform.c * transform.ty - transform.d * transform.tx) * invDet,
      ty: (transform.b * transform.tx - transform.a * transform.ty) * invDet,
    );
  }

  static int resolveChildFrame(TimelineElement element, int parentFrame, int instanceStart, int childTotal) {
    if (childTotal <= 0) return 0;
    var rel = parentFrame - instanceStart;
    if (rel < 0) rel = 0;
    final base = rel + element.firstFrame;
    final loop = element.loop.trim().toLowerCase();
    if (loop == 'sf' || loop == 'singleframe' || loop == 'single_frame') {
      return tools.clampInt(element.firstFrame, 0, childTotal - 1);
    }
    if (loop == 'po' || loop == 'playonce' || loop == 'play_once') {
      return base < childTotal ? base : childTotal - 1;
    }
    final safeBase = base < 0 ? 0 : base;
    return safeBase % childTotal;
  }

  static void accumulateBoundsSymbol(
    SymbolDef symbol,
    int frame,
    Transform parent,
    Map<String, SymbolDef> symbols,
    Map<String, AtlasSpriteDef> atlas,
    Bounds bounds,
  ) {
    for (final layer in symbol.timeline.layers) {
      final activeFrame = _findActiveFrame(layer, frame);
      if (activeFrame == null) continue;
      for (final element in activeFrame.elements) {
        final transform = multiply(parent, element.transform);
        if (element.type == ElementType.atlasSprite) {
          final sprite = atlas[element.name];
          if (sprite == null) continue;
          final drawWidth = sprite.rotated ? sprite.h : sprite.w;
          final drawHeight = sprite.rotated ? sprite.w : sprite.h;
          _includeSpriteBounds(bounds, transform, drawWidth, drawHeight);
        } else {
          final child = symbols[element.name];
          if (child == null) continue;
          final childFrame = resolveChildFrame(element, frame, activeFrame.start, child.timeline.totalFrames);
          accumulateBoundsSymbol(child, childFrame, transform, symbols, atlas, bounds);
        }
      }
    }
  }

  static void renderSymbol(
    SymbolDef symbol,
    int frame,
    Transform parent,
    Map<String, SymbolDef> symbols,
    Map<String, AtlasSpriteDef> atlas,
    RgbaImage atlasImage,
    RgbaImage canvas,
  ) {
    for (var li = symbol.timeline.layers.length - 1; li >= 0; li--) {
      final layer = symbol.timeline.layers[li];
      final activeFrame = _findActiveFrame(layer, frame);
      if (activeFrame == null) continue;
      for (final element in activeFrame.elements) {
        final transform = multiply(parent, element.transform);
        if (element.type == ElementType.atlasSprite) {
          final sprite = atlas[element.name];
          if (sprite != null) drawSpriteAffine(atlasImage, sprite, transform, canvas);
        } else {
          final child = symbols[element.name];
          if (child == null) continue;
          final childFrame = resolveChildFrame(element, frame, activeFrame.start, child.timeline.totalFrames);
          renderSymbol(child, childFrame, transform, symbols, atlas, atlasImage, canvas);
        }
      }
    }
  }

  static void drawSpriteAffine(RgbaImage atlasImage, AtlasSpriteDef sprite, Transform transform, RgbaImage canvas) {
    final drawWidth = sprite.rotated ? sprite.h : sprite.w;
    final drawHeight = sprite.rotated ? sprite.w : sprite.h;
    if (drawWidth <= 0 || drawHeight <= 0) return;

    final x0 = transform.tx;
    final y0 = transform.ty;
    final x1 = transform.a * drawWidth + transform.tx;
    final y1 = transform.b * drawWidth + transform.ty;
    final x2 = transform.c * drawHeight + transform.tx;
    final y2 = transform.d * drawHeight + transform.ty;
    final x3 = transform.a * drawWidth + transform.c * drawHeight + transform.tx;
    final y3 = transform.b * drawWidth + transform.d * drawHeight + transform.ty;

    final minx = tools.min4(x0, x1, x2, x3).floor();
    final maxx = tools.max4(x0, x1, x2, x3).ceil();
    final miny = tools.min4(y0, y1, y2, y3).floor();
    final maxy = tools.max4(y0, y1, y2, y3).ceil();
    final inverse = invert(transform);
    if (inverse == null) return;

    final ix0 = tools.clampInt(minx, 0, canvas.width - 1);
    final ix1 = tools.clampInt(maxx, 0, canvas.width - 1);
    final iy0 = tools.clampInt(miny, 0, canvas.height - 1);
    final iy1 = tools.clampInt(maxy, 0, canvas.height - 1);

    for (var y = iy0; y <= iy1; y++) {
      for (var x = ix0; x <= ix1; x++) {
        final sx = inverse.a * x + inverse.c * y + inverse.tx;
        final sy = inverse.b * x + inverse.d * y + inverse.ty;
        if (sx < 0 || sy < 0 || sx >= drawWidth || sy >= drawHeight) continue;

        final ax = !sprite.rotated ? sprite.x + sx.toInt() : sprite.x + (sprite.w - 1 - sy.toInt());
        final ay = !sprite.rotated ? sprite.y + sy.toInt() : sprite.y + sx.toInt();
        if (ax < 0 || ay < 0 || ax >= atlasImage.width || ay >= atlasImage.height) continue;

        final srcOffset = atlasImage.pixelOffset(ax, ay);
        if (atlasImage.pixels[srcOffset + 3] == 0) continue;
        _blendPixel(canvas, canvas.pixelOffset(x, y), atlasImage, srcOffset);
      }
    }
  }

  static void _blendPixel(RgbaImage dst, int dstOffset, RgbaImage src, int srcOffset) {
    final sr = src.pixels[srcOffset] / 255;
    final sg = src.pixels[srcOffset + 1] / 255;
    final sb = src.pixels[srcOffset + 2] / 255;
    final sa = src.pixels[srcOffset + 3] / 255;
    final dr = dst.pixels[dstOffset] / 255;
    final dg = dst.pixels[dstOffset + 1] / 255;
    final db = dst.pixels[dstOffset + 2] / 255;
    final da = dst.pixels[dstOffset + 3] / 255;
    final outA = sa + da * (1 - sa);

    if (outA <= 0) {
      dst.pixels[dstOffset] = 0;
      dst.pixels[dstOffset + 1] = 0;
      dst.pixels[dstOffset + 2] = 0;
      dst.pixels[dstOffset + 3] = 0;
      return;
    }

    dst.pixels[dstOffset] = tools.clampChannel(((sr * sa + dr * da * (1 - sa)) / outA) * 255);
    dst.pixels[dstOffset + 1] = tools.clampChannel(((sg * sa + dg * da * (1 - sa)) / outA) * 255);
    dst.pixels[dstOffset + 2] = tools.clampChannel(((sb * sa + db * da * (1 - sa)) / outA) * 255);
    dst.pixels[dstOffset + 3] = tools.clampChannel(outA * 255);
  }

  static void _includeSpriteBounds(Bounds bounds, Transform transform, int drawWidth, int drawHeight) {
    final x0 = transform.tx;
    final y0 = transform.ty;
    final x1 = transform.a * drawWidth + transform.tx;
    final y1 = transform.b * drawWidth + transform.ty;
    final x2 = transform.c * drawHeight + transform.tx;
    final y2 = transform.d * drawHeight + transform.ty;
    final x3 = transform.a * drawWidth + transform.c * drawHeight + transform.tx;
    final y3 = transform.b * drawWidth + transform.d * drawHeight + transform.ty;
    bounds.include(
      tools.min4(x0, x1, x2, x3).toDouble(),
      tools.min4(y0, y1, y2, y3).toDouble(),
      tools.max4(x0, x1, x2, x3).toDouble(),
      tools.max4(y0, y1, y2, y3).toDouble(),
    );
  }

  static TimelineFrame? _findActiveFrame(TimelineLayer layer, int frame) {
    for (final candidate in layer.frames) {
      if (frame >= candidate.start && frame < candidate.start + candidate.duration) {
        return candidate;
      }
    }
    return null;
  }
}
