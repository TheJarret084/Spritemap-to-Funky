package backend;

import backend.Model.AnimDef;
import backend.Model.AtlasSpriteDef;
import backend.Model.ElementType;
import backend.Model.TimelineData;
import backend.Model.TimelineElement;
import backend.Model.TimelineFrame;
import backend.Model.TimelineLayer;
import backend.Model.Transform;

class Parser {
    public static function parseAnimXml(path:String):Array<AnimDef> {
        var out:Array<AnimDef> = [];
        var xml = Xml.parse(Tools.readFileStripBom(path));

        for (root in xml.elements()) {
            collectAnimNodes(root, out);
        }

        return out;
    }

    static function collectAnimNodes(node:Xml, out:Array<AnimDef>):Void {
        if (node.nodeName == "anim") {
            var name = node.get("name");
            var source = node.get("anim");
            if (!Tools.isBlank(name) && !Tools.isBlank(source)) {
                out.push(new AnimDef(name, source, Tools.parseIndices(node.get("indices"))));
            }
        }

        for (child in node.elements()) {
            collectAnimNodes(child, out);
        }
    }

    public static function parseM3d(raw:Dynamic):Transform {
        var transform = new Transform();
        if (raw != null && !Std.isOfType(raw, Array)) {
            transform.a = Tools.floatValue(Tools.field(raw, "m00"), 1.0);
            transform.b = Tools.floatValue(Tools.field(raw, "m01"), 0.0);
            transform.c = Tools.floatValue(Tools.field(raw, "m10"), 0.0);
            transform.d = Tools.floatValue(Tools.field(raw, "m11"), 1.0);
            transform.tx = Tools.floatValue(Tools.field(raw, "m30"), 0.0);
            transform.ty = Tools.floatValue(Tools.field(raw, "m31"), 0.0);
            return transform;
        }

        var values = Tools.asArray(raw);
        if (values.length < 16) return transform;

        transform.a = Tools.floatValue(values[0], 1.0);
        transform.b = Tools.floatValue(values[1], 0.0);
        transform.c = Tools.floatValue(values[4], 0.0);
        transform.d = Tools.floatValue(values[5], 1.0);
        transform.tx = Tools.floatValue(values[12], 0.0);
        transform.ty = Tools.floatValue(values[13], 0.0);
        return transform;
    }

    public static function parseMx(raw:Dynamic):Transform {
        var transform = new Transform();
        var values = Tools.asArray(raw);
        if (values.length < 6) return transform;

        transform.a = Tools.floatValue(values[0], 1.0);
        transform.b = Tools.floatValue(values[1], 0.0);
        transform.c = Tools.floatValue(values[2], 0.0);
        transform.d = Tools.floatValue(values[3], 1.0);
        transform.tx = Tools.floatValue(values[4], 0.0);
        transform.ty = Tools.floatValue(values[5], 0.0);
        return transform;
    }

    static function parseCompactTransform(raw:Dynamic):Transform {
        var mx = Tools.field(raw, "MX");
        if (mx != null) return parseMx(mx);
        return parseM3d(Tools.field(raw, "M3D"));
    }

    public static function parseTimeline(raw:Dynamic):TimelineData {
        var timeline = new TimelineData();
        var maxEnd = 0;

        var compactLayers = Tools.arrayField(raw, "L");
        if (compactLayers.length > 0) {
            parseCompactLayers(compactLayers, timeline);
        } else {
            parseVerboseLayers(Tools.arrayField(raw, "LAYERS"), timeline);
        }

        for (layer in timeline.layers) {
            for (frame in layer.frames) {
                var frameEnd = frame.start + frame.duration;
                if (frameEnd > maxEnd) maxEnd = frameEnd;
            }
        }

        timeline.totalFrames = maxEnd;
        return timeline;
    }

    static function parseCompactLayers(layers:Array<Dynamic>, timeline:TimelineData):Void {
        for (layerJson in layers) {
            var layer = new TimelineLayer();

            for (frameJson in Tools.arrayField(layerJson, "FR")) {
                var frame = new TimelineFrame();
                frame.start = Tools.intField(frameJson, "I", 0);
                frame.duration = Tools.intField(frameJson, "DU", 1);

                for (elementJson in Tools.arrayField(frameJson, "E")) {
                    var atlasSprite = Tools.field(elementJson, "ASI");
                    if (atlasSprite != null) {
                        var atlasElement = new TimelineElement(ElementType.AtlasSprite);
                        atlasElement.name = Tools.stringField(atlasSprite, "N", "");
                        atlasElement.transform = parseCompactTransform(atlasSprite);
                        frame.elements.push(atlasElement);
                        continue;
                    }

                    var symbolInstance = Tools.field(elementJson, "SI");
                    if (symbolInstance != null) {
                        var symbolElement = new TimelineElement(ElementType.SymbolInstance);
                        symbolElement.name = Tools.stringField(symbolInstance, "SN", "");
                        symbolElement.firstFrame = Tools.intField(symbolInstance, "FF", 0);
                        symbolElement.symbolType = Tools.stringField(symbolInstance, "ST", "");
                        symbolElement.loop = Tools.stringField(symbolInstance, "LP", "");
                        symbolElement.transform = parseCompactTransform(symbolInstance);
                        frame.elements.push(symbolElement);
                    }
                }

                layer.frames.push(frame);
            }

            timeline.layers.push(layer);
        }
    }

    static function parseVerboseLayers(layers:Array<Dynamic>, timeline:TimelineData):Void {
        for (layerJson in layers) {
            var layer = new TimelineLayer();

            for (frameJson in Tools.arrayField(layerJson, "Frames")) {
                var frame = new TimelineFrame();
                frame.start = Tools.intField(frameJson, "index", 0);
                frame.duration = Tools.intField(frameJson, "duration", 1);

                for (elementJson in Tools.arrayField(frameJson, "elements")) {
                    var atlasSprite = Tools.field(elementJson, "ATLAS_SPRITE_instance");
                    if (atlasSprite != null) {
                        var atlasElement = new TimelineElement(ElementType.AtlasSprite);
                        atlasElement.name = Tools.stringField(atlasSprite, "name", "");
                        atlasElement.transform = Parser.parseM3d(Tools.field(atlasSprite, "Matrix3D"));
                        applyDecomposedFallback(atlasElement.transform, Tools.field(atlasSprite, "DecomposedMatrix"));
                        frame.elements.push(atlasElement);
                        continue;
                    }

                    var symbolInstance = Tools.field(elementJson, "SYMBOL_Instance");
                    if (symbolInstance != null) {
                        var symbolElement = new TimelineElement(ElementType.SymbolInstance);
                        symbolElement.name = Tools.stringField(symbolInstance, "SYMBOL_name", "");
                        symbolElement.firstFrame = Tools.intField(symbolInstance, "firstFrame", 0);
                        symbolElement.symbolType = Tools.stringField(symbolInstance, "symbolType", "");
                        symbolElement.loop = Tools.stringField(symbolInstance, "loop", "");
                        if (Tools.isBlank(symbolElement.loop) && normalize(symbolElement.symbolType) == "movieclip")
                            symbolElement.loop = "singleframe";
                        symbolElement.transform = Parser.parseM3d(Tools.field(symbolInstance, "Matrix3D"));
                        applyDecomposedFallback(symbolElement.transform, Tools.field(symbolInstance, "DecomposedMatrix"));
                        frame.elements.push(symbolElement);
                    }
                }

                layer.frames.push(frame);
            }

            timeline.layers.push(layer);
        }
    }

    static function applyDecomposedFallback(transform:Transform, decomposed:Dynamic):Void {
        if (decomposed == null) return;

        var rotation = Tools.field(decomposed, "Rotation");
        var rx = Tools.floatValue(Tools.field(rotation, "x"), 0.0);
        var ry = Tools.floatValue(Tools.field(rotation, "y"), 0.0);
        var rz = Tools.floatValue(Tools.field(rotation, "z"), 0.0);
        var noRotation = Math.abs(rx) < 1e-6 && Math.abs(ry) < 1e-6 && Math.abs(rz) < 1e-6;
        if (!noRotation || (Math.abs(transform.b) <= 1e-6 && Math.abs(transform.c) <= 1e-6)) return;

        var scaling = Tools.field(decomposed, "Scaling");
        var position = Tools.field(decomposed, "Position");
        var sx = Tools.floatValue(Tools.field(scaling, "x"), 1.0);
        var sy = Tools.floatValue(Tools.field(scaling, "y"), 1.0);
        var px = Tools.floatValue(Tools.field(position, "x"), 0.0);
        var py = Tools.floatValue(Tools.field(position, "y"), 0.0);
        var cr = Math.cos(rz);
        var sr = Math.sin(rz);

        transform.a = cr * sx;
        transform.b = sr * sx;
        transform.c = -sr * sy;
        transform.d = cr * sy;
        transform.tx = px;
        transform.ty = py;
    }

    static function normalize(value:String):String {
        if (value == null) return "";
        return StringTools.trim(value).toLowerCase();
    }
}
