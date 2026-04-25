package backend;

import backend.Model.AtlasSpriteDef;
import backend.Model.Bounds;
import backend.Model.ElementType;
import backend.Model.RgbaImage;
import backend.Model.SymbolDef;
import backend.Model.TimelineElement;
import backend.Model.TimelineFrame;
import backend.Model.TimelineLayer;
import backend.Model.Transform;

class Renderer {
    public static function multiply(parent:Transform, local:Transform):Transform {
        var result = new Transform();
        result.a = parent.a * local.a + parent.c * local.b;
        result.b = parent.b * local.a + parent.d * local.b;
        result.c = parent.a * local.c + parent.c * local.d;
        result.d = parent.b * local.c + parent.d * local.d;
        result.tx = parent.a * local.tx + parent.c * local.ty + parent.tx;
        result.ty = parent.b * local.tx + parent.d * local.ty + parent.ty;
        return result;
    }

    public static function invert(transform:Transform):Transform {
        var det = transform.a * transform.d - transform.b * transform.c;
        if (Math.abs(det) < 1e-10) return null;

        var invDet = 1.0 / det;
        var inverse = new Transform();
        inverse.a = transform.d * invDet;
        inverse.b = -transform.b * invDet;
        inverse.c = -transform.c * invDet;
        inverse.d = transform.a * invDet;
        inverse.tx = (transform.c * transform.ty - transform.d * transform.tx) * invDet;
        inverse.ty = (transform.b * transform.tx - transform.a * transform.ty) * invDet;
        return inverse;
    }

    public static function resolveChildFrame(element:TimelineElement, parentFrame:Int, instanceStart:Int, childTotal:Int):Int {
        if (childTotal <= 0) return 0;

        var rel = parentFrame - instanceStart;
        if (rel < 0) rel = 0;

        var base = rel + element.firstFrame;
        if (element.loop == "SF") {
            return Tools.clampInt(element.firstFrame, 0, childTotal - 1);
        }

        if (element.loop == "PO") {
            return base < childTotal ? base : childTotal - 1;
        }

        if (base < 0) base = 0;
        return childTotal == 0 ? 0 : base % childTotal;
    }

    public static function accumulateBoundsSymbol(
        symbol:SymbolDef,
        frame:Int,
        parent:Transform,
        symbols:Map<String, SymbolDef>,
        atlas:Map<String, AtlasSpriteDef>,
        bounds:Bounds
    ):Void {
        for (layer in symbol.timeline.layers) {
            var activeFrame = findActiveFrame(layer, frame);
            if (activeFrame == null) continue;

            for (element in activeFrame.elements) {
                var transform = multiply(parent, element.transform);

                if (element.type == ElementType.AtlasSprite) {
                    var sprite = atlas.get(element.name);
                    if (sprite == null) continue;

                    var drawWidth = sprite.rotated ? sprite.h : sprite.w;
                    var drawHeight = sprite.rotated ? sprite.w : sprite.h;
                    includeSpriteBounds(bounds, transform, drawWidth, drawHeight);
                } else {
                    var child = symbols.get(element.name);
                    if (child == null) continue;

                    var childFrame = resolveChildFrame(element, frame, activeFrame.start, child.timeline.totalFrames);
                    accumulateBoundsSymbol(child, childFrame, transform, symbols, atlas, bounds);
                }
            }
        }
    }

    public static function renderSymbol(
        symbol:SymbolDef,
        frame:Int,
        parent:Transform,
        symbols:Map<String, SymbolDef>,
        atlas:Map<String, AtlasSpriteDef>,
        atlasImage:RgbaImage,
        canvas:RgbaImage
    ):Void {
        var li = symbol.timeline.layers.length - 1;
        while (li >= 0) {
            var layer = symbol.timeline.layers[li];
            var activeFrame = findActiveFrame(layer, frame);
            if (activeFrame != null) {
                for (element in activeFrame.elements) {
                    var transform = multiply(parent, element.transform);

                    if (element.type == ElementType.AtlasSprite) {
                        var sprite = atlas.get(element.name);
                        if (sprite != null) {
                            drawSpriteAffine(atlasImage, sprite, transform, canvas);
                        }
                    } else {
                        var child = symbols.get(element.name);
                        if (child == null) continue;

                        var childFrame = resolveChildFrame(element, frame, activeFrame.start, child.timeline.totalFrames);
                        renderSymbol(child, childFrame, transform, symbols, atlas, atlasImage, canvas);
                    }
                }
            }

            li--;
        }
    }

    public static function visitElements(
        symbol:SymbolDef,
        frame:Int,
        parent:Transform,
        prefix:String,
        occ:Map<String, Int>,
        symbols:Map<String, SymbolDef>,
        atlas:Map<String, AtlasSpriteDef>,
        onSprite:(AtlasSpriteDef, Transform, String) -> Void
    ):Void {
        var li = symbol.timeline.layers.length - 1;
        while (li >= 0) {
            var layer = symbol.timeline.layers[li];
            var activeFrame = findActiveFrame(layer, frame);
            if (activeFrame != null) {
                for (element in activeFrame.elements) {
                    var transform = multiply(parent, element.transform);
                    var base = prefix + symbol.name + "_L" + li + "_" + element.name + "_" +
                        (element.type == ElementType.AtlasSprite ? "A" : "S");
                    var index = occ.exists(base) ? occ.get(base) : 0;
                    occ.set(base, index + 1);

                    var raw = index > 0 ? base + "_" + index : base;

                    if (element.type == ElementType.AtlasSprite) {
                        var sprite = atlas.get(element.name);
                        if (sprite != null) {
                            onSprite(sprite, transform, raw);
                        }
                    } else {
                        var child = symbols.get(element.name);
                        if (child == null) continue;

                        var childFrame = resolveChildFrame(element, frame, activeFrame.start, child.timeline.totalFrames);
                        visitElements(child, childFrame, transform, raw + "__", occ, symbols, atlas, onSprite);
                    }
                }
            }

            li--;
        }
    }

    public static function drawSpriteAffine(atlasImage:RgbaImage, sprite:AtlasSpriteDef, transform:Transform, canvas:RgbaImage):Void {
        var drawWidth = sprite.rotated ? sprite.h : sprite.w;
        var drawHeight = sprite.rotated ? sprite.w : sprite.h;
        if (drawWidth <= 0 || drawHeight <= 0) return;

        var x0 = transform.tx;
        var y0 = transform.ty;
        var x1 = transform.a * drawWidth + transform.tx;
        var y1 = transform.b * drawWidth + transform.ty;
        var x2 = transform.c * drawHeight + transform.tx;
        var y2 = transform.d * drawHeight + transform.ty;
        var x3 = transform.a * drawWidth + transform.c * drawHeight + transform.tx;
        var y3 = transform.b * drawWidth + transform.d * drawHeight + transform.ty;

        var minx = Math.floor(Math.min(Math.min(x0, x1), Math.min(x2, x3)));
        var maxx = Math.ceil(Math.max(Math.max(x0, x1), Math.max(x2, x3)));
        var miny = Math.floor(Math.min(Math.min(y0, y1), Math.min(y2, y3)));
        var maxy = Math.ceil(Math.max(Math.max(y0, y1), Math.max(y2, y3)));

        var inverse = invert(transform);
        if (inverse == null) return;

        var ix0 = Tools.clampInt(Std.int(minx), 0, canvas.width - 1);
        var ix1 = Tools.clampInt(Std.int(maxx), 0, canvas.width - 1);
        var iy0 = Tools.clampInt(Std.int(miny), 0, canvas.height - 1);
        var iy1 = Tools.clampInt(Std.int(maxy), 0, canvas.height - 1);

        for (y in iy0...iy1 + 1) {
            for (x in ix0...ix1 + 1) {
                var sx = inverse.a * x + inverse.c * y + inverse.tx;
                var sy = inverse.b * x + inverse.d * y + inverse.ty;
                if (sx < 0.0 || sy < 0.0 || sx >= drawWidth || sy >= drawHeight) continue;

                var ax:Int;
                var ay:Int;
                if (!sprite.rotated) {
                    ax = sprite.x + Std.int(sx);
                    ay = sprite.y + Std.int(sy);
                } else {
                    ax = sprite.x + (sprite.w - 1 - Std.int(sy));
                    ay = sprite.y + Std.int(sx);
                }

                if (ax < 0 || ay < 0 || ax >= atlasImage.width || ay >= atlasImage.height) continue;

                var srcOffset = atlasImage.pixelOffset(ax, ay);
                var srcAlpha = atlasImage.pixels.get(srcOffset + 3);
                if (srcAlpha == 0) continue;

                var dstOffset = canvas.pixelOffset(x, y);
                blendPixel(canvas, dstOffset, atlasImage, srcOffset);
            }
        }
    }

    static function blendPixel(dst:RgbaImage, dstOffset:Int, src:RgbaImage, srcOffset:Int):Void {
        var sr = src.pixels.get(srcOffset) / 255.0;
        var sg = src.pixels.get(srcOffset + 1) / 255.0;
        var sb = src.pixels.get(srcOffset + 2) / 255.0;
        var sa = src.pixels.get(srcOffset + 3) / 255.0;

        var dr = dst.pixels.get(dstOffset) / 255.0;
        var dg = dst.pixels.get(dstOffset + 1) / 255.0;
        var db = dst.pixels.get(dstOffset + 2) / 255.0;
        var da = dst.pixels.get(dstOffset + 3) / 255.0;

        var outA = sa + da * (1.0 - sa);
        if (outA <= 0.0) {
            dst.pixels.set(dstOffset, 0);
            dst.pixels.set(dstOffset + 1, 0);
            dst.pixels.set(dstOffset + 2, 0);
            dst.pixels.set(dstOffset + 3, 0);
            return;
        }

        var outR = (sr * sa + dr * da * (1.0 - sa)) / outA;
        var outG = (sg * sa + dg * da * (1.0 - sa)) / outA;
        var outB = (sb * sa + db * da * (1.0 - sa)) / outA;

        dst.pixels.set(dstOffset, clampChannel(outR * 255.0));
        dst.pixels.set(dstOffset + 1, clampChannel(outG * 255.0));
        dst.pixels.set(dstOffset + 2, clampChannel(outB * 255.0));
        dst.pixels.set(dstOffset + 3, clampChannel(outA * 255.0));
    }

    static function clampChannel(value:Float):Int {
        var intValue = Std.int(Math.round(value));
        return Tools.clampInt(intValue, 0, 255);
    }

    static function includeSpriteBounds(bounds:Bounds, transform:Transform, drawWidth:Int, drawHeight:Int):Void {
        var x0 = transform.tx;
        var y0 = transform.ty;
        var x1 = transform.a * drawWidth + transform.tx;
        var y1 = transform.b * drawWidth + transform.ty;
        var x2 = transform.c * drawHeight + transform.tx;
        var y2 = transform.d * drawHeight + transform.ty;
        var x3 = transform.a * drawWidth + transform.c * drawHeight + transform.tx;
        var y3 = transform.b * drawWidth + transform.d * drawHeight + transform.ty;

        bounds.include(
            Math.min(Math.min(x0, x1), Math.min(x2, x3)),
            Math.min(Math.min(y0, y1), Math.min(y2, y3)),
            Math.max(Math.max(x0, x1), Math.max(x2, x3)),
            Math.max(Math.max(y0, y1), Math.max(y2, y3))
        );
    }

    static function findActiveFrame(layer:TimelineLayer, frame:Int):TimelineFrame {
        for (candidate in layer.frames) {
            if (frame >= candidate.start && frame < candidate.start + candidate.duration) {
                return candidate;
            }
        }
        return null;
    }
}
