package;

import haxe.Json;
import haxe.io.Path;
import openfl.display.BitmapData;
import Model.AnimationChoice;
import Model.ExportResult;
import Model.LoadResult;
import Model.ProjectPaths;

#if sys
import sys.FileSystem;
#end

class Backend {
    public static function loadProject(paths:ProjectPaths):LoadResult {
        var response = callNativeDescribe(paths);
        return new LoadResult(
            parseAnimations(field(response, "animations")),
            stringField(response, "previewPath"),
            stringField(response, "log")
        );
    }

    public static function exportProject(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool):ExportResult {
        var request:Dynamic = buildBaseRequest(paths);
        Reflect.setField(request, "selected", toSelectionPayload(choices));
        Reflect.setField(request, "exportFrames", exportFrames);
        Reflect.setField(request, "exportAse", false);
        Reflect.setField(request, "asepritePath", "aseprite");

        var response = parseJsonResponse(Native.exportProject(Json.stringify(request)));
        return new ExportResult(
            stringField(response, "log"),
            stringField(response, "outputDir"),
            intField(response, "filesWritten", 0)
        );
    }

    public static function resolvePreviewPath(paths:ProjectPaths, ?log:Array<String>):String {
        var response = callNativeDescribe(paths);
        var message = stringField(response, "log");
        if (log != null && !isBlank(message)) log.push(message);
        return stringField(response, "previewPath");
    }

    public static function loadPreviewBitmap(path:String):BitmapData {
        if (isBlank(path)) return null;
        return BitmapData.fromFile(path);
    }

    public static function discoverSamplePaths():ProjectPaths {
        #if sys
        var candidates = [
            Path.join([Sys.getCwd(), "assets", "sample"]),
            Path.join([Sys.getCwd(), "bin", "assets", "sample"]),
            Path.join([Sys.getCwd(), "..", "assets", "sample"]),
            Path.join([Sys.getCwd(), "..", "..", "assets", "sample"]),
            Path.join([Sys.getCwd(), "..", "..", "..", "assets", "sample"])
        ];

        for (candidate in candidates) {
            var animationJson = Path.join([candidate, "Animation.json"]);
            var atlasJson = Path.join([candidate, "spritemap1.json"]);
            var xmlPath = Path.join([candidate, "anims.xml"]);
            if (fileExists(animationJson) && fileExists(atlasJson)) {
                var paths = new ProjectPaths();
                paths.animationJson = FileSystem.fullPath(animationJson);
                paths.atlasJson = FileSystem.fullPath(atlasJson);
                if (fileExists(xmlPath)) paths.animsXml = FileSystem.fullPath(xmlPath);
                paths.outputDir = Path.join([Sys.getCwd(), "out", "sample"]);
                return paths;
            }
        }
        #end

        return null;
    }

    static function callNativeDescribe(paths:ProjectPaths):Dynamic {
        return parseJsonResponse(Native.describeProject(Json.stringify(buildBaseRequest(paths))));
    }

    static function buildBaseRequest(paths:ProjectPaths):Dynamic {
        return {
            animationJson: paths.animationJson,
            atlasJson: paths.atlasJson,
            atlasPng: paths.atlasPng,
            animsXml: paths.animsXml,
            animsJson: paths.animsJson,
            outputDir: paths.outputDir
        };
    }

    static function parseJsonResponse(raw:String):Dynamic {
        if (isBlank(raw)) {
            return { ok: false, log: "El backend devolvió una respuesta vacía." };
        }

        try {
            return Json.parse(raw);
        } catch (error:Dynamic) {
            return { ok: false, log: "No pude parsear la respuesta del backend: " + Std.string(error) + "\n" + raw };
        }
    }

    static function parseAnimations(raw:Dynamic):Array<AnimationChoice> {
        var out:Array<AnimationChoice> = [];
        if (!Std.isOfType(raw, Array)) return out;

        for (item in cast(raw, Array<Dynamic>)) {
            var name = stringField(item, "name");
            var source = stringField(item, "source");
            if (isBlank(name) || isBlank(source)) continue;
            out.push(new AnimationChoice(name, source, parseIndices(field(item, "indices")), true));
        }
        return out;
    }

    static function toSelectionPayload(choices:Array<AnimationChoice>):Array<Dynamic> {
        var out:Array<Dynamic> = [];
        if (choices == null) return out;

        for (choice in choices) {
            if (choice == null || !choice.selected) continue;
            out.push({
                name: choice.name,
                source: choice.source,
                indices: choice.indices
            });
        }
        return out;
    }

    static function parseIndices(raw:Dynamic):Array<Int> {
        var out:Array<Int> = [];
        if (!Std.isOfType(raw, Array)) return out;
        for (value in cast(raw, Array<Dynamic>)) {
            if (value != null) out.push(Std.int(value));
        }
        return out;
    }

    static function field(value:Dynamic, name:String):Dynamic {
        return value != null && Reflect.hasField(value, name) ? Reflect.field(value, name) : null;
    }

    static function stringField(value:Dynamic, name:String, fallback:String = ""):String {
        var result = field(value, name);
        return result == null ? fallback : Std.string(result);
    }

    static function intField(value:Dynamic, name:String, fallback:Int):Int {
        var result = field(value, name);
        return result == null ? fallback : Std.int(result);
    }

    static function isBlank(value:String):Bool {
        return value == null || StringTools.trim(value) == "";
    }

    static function fileExists(path:String):Bool {
        #if sys
        return !isBlank(path) && FileSystem.exists(path);
        #else
        return false;
        #end
    }
}
