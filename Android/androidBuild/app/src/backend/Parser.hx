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

    public static function parseTimeline(raw:Dynamic):TimelineData {
        var timeline = new TimelineData();
        var maxEnd = 0;

        for (layerJson in Tools.arrayField(raw, "L")) {
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
                        atlasElement.transform = Parser.parseM3d(Tools.field(atlasSprite, "M3D"));
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
                        symbolElement.transform = Parser.parseM3d(Tools.field(symbolInstance, "M3D"));
                        frame.elements.push(symbolElement);
                    }
                }

                layer.frames.push(frame);
                var frameEnd = frame.start + frame.duration;
                if (frameEnd > maxEnd) maxEnd = frameEnd;
            }

            timeline.layers.push(layer);
        }

        timeline.totalFrames = maxEnd;
        return timeline;
    }
}
