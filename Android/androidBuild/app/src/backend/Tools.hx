package backend;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class Tools {
    public static function isBlank(value:String):Bool {
        return value == null || StringTools.trim(value) == "";
    }

    public static function readFileStripBom(path:String):String {
        var content = File.getContent(path);
        if (StringTools.startsWith(content, "\ufeff")) {
            return content.substr(1);
        }
        return content;
    }

    public static function splitCsv(value:String):Array<String> {
        if (isBlank(value)) return [];
        return value.split(",");
    }

    public static function parseIndices(value:String):Array<Int> {
        var out:Array<Int> = [];
        if (isBlank(value)) return out;

        for (part in splitCsv(value)) {
            var clean = StringTools.trim(part);
            if (clean == "") continue;

            var dots = clean.indexOf("..");
            if (dots != -1) {
                var a = Std.parseInt(clean.substr(0, dots));
                var b = Std.parseInt(clean.substr(dots + 2));
                if (a == null || b == null) continue;

                if (a <= b) {
                    for (i in a...b + 1) out.push(i);
                } else {
                    var current = a;
                    while (current >= b) {
                        out.push(current);
                        current--;
                    }
                }
            } else {
                var parsed = Std.parseInt(clean);
                if (parsed != null) out.push(parsed);
            }
        }

        return out;
    }

    public static function sanitizeName(value:String):String {
        if (isBlank(value)) return "main";

        var out = value;
        out = StringTools.replace(out, " ", "_");

        for (bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]) {
            out = StringTools.replace(out, bad, "_");
        }

        return out;
    }

    public static function field(value:Dynamic, name:String):Dynamic {
        return value != null && Reflect.hasField(value, name) ? Reflect.field(value, name) : null;
    }

    public static function asArray(value:Dynamic):Array<Dynamic> {
        return value != null && Std.isOfType(value, Array) ? cast value : [];
    }

    public static function arrayField(value:Dynamic, name:String):Array<Dynamic> {
        return asArray(field(value, name));
    }

    public static function stringField(value:Dynamic, name:String, fallback:String = ""):String {
        var result = field(value, name);
        return result == null ? fallback : Std.string(result);
    }

    public static function intField(value:Dynamic, name:String, fallback:Int = 0):Int {
        var result = field(value, name);
        return result == null ? fallback : Std.int(result);
    }

    public static function boolField(value:Dynamic, name:String, fallback:Bool = false):Bool {
        var result = field(value, name);
        if (result == null) return fallback;
        if (Std.isOfType(result, Bool)) return cast result;

        var text = Std.string(result).toLowerCase();
        return text == "true" || text == "1";
    }

    public static function floatValue(value:Dynamic, fallback:Float = 0.0):Float {
        if (value == null) return fallback;
        var parsed = Std.parseFloat(Std.string(value));
        return Math.isNaN(parsed) ? fallback : parsed;
    }

    public static function fileExists(path:String):Bool {
        return !isBlank(path) && FileSystem.exists(path) && !FileSystem.isDirectory(path);
    }

    public static function directoryExists(path:String):Bool {
        return !isBlank(path) && FileSystem.exists(path) && FileSystem.isDirectory(path);
    }

    public static function ensureDirectory(path:String):Void {
        if (isBlank(path) || directoryExists(path)) return;

        var parent = Path.directory(path);
        if (!isBlank(parent) && parent != path && !directoryExists(parent)) {
            ensureDirectory(parent);
        }

        if (!directoryExists(path)) {
            FileSystem.createDirectory(path);
        }
    }

    public static function joinLines(lines:Array<String>):String {
        var out:Array<String> = [];
        if (lines == null) return "";

        for (line in lines) {
            if (!isBlank(line)) out.push(line);
        }

        return out.join("\n");
    }

    public static function makeError(message:String, ?logs:Array<String>):Dynamic {
        return {
            ok: false,
            log: logs != null && logs.length > 0 ? joinLines(logs) + "\n" + message : message
        };
    }

    public static function stem(path:String):String {
        return Path.withoutExtension(Path.withoutDirectory(path));
    }

    public static function resolvePreviewPath(atlasJson:String, atlasPng:String):String {
        return resolveAtlasPngPath(atlasJson, atlasPng);
    }

    public static function resolveAtlasPngPath(atlasJson:String, atlasPng:String):String {
        if (fileExists(atlasPng)) return atlasPng;
        if (!fileExists(atlasJson)) return "";

        var data = Json.parse(readFileStripBom(atlasJson));
        var image = "spritemap1.png";
        var atlas = field(data, "ATLAS");
        var meta = field(atlas, "meta");
        if (meta != null) image = stringField(meta, "image", image);

        var dir = Path.directory(atlasJson);
        return dir == "" ? image : Path.join([dir, image]);
    }

    public static function resolveOutputDir(
        animationJson:String,
        animsXml:String,
        animsJson:String,
        outputDir:String
    ):String {
        if (!isBlank(outputDir)) return outputDir;

        var base = "";
        if (!isBlank(animsJson)) {
            base = stem(animsJson);
        } else if (!isBlank(animsXml)) {
            base = stem(animsXml);
        } else if (!isBlank(animationJson)) {
            var dir = Path.directory(animationJson);
            base = isBlank(dir) ? "" : Path.withoutDirectory(dir);
        }

        if (isBlank(base)) base = "project";
        return Path.join(["out", base]);
    }

    public static function clampInt(value:Int, minValue:Int, maxValue:Int):Int {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }

    public static function formatFrameIndex(index:Int):String {
        return StringTools.lpad(Std.string(index), "0", 4);
    }

    public static function luaEscape(value:String):String {
        var out = value;
        out = StringTools.replace(out, "\\", "\\\\");
        out = StringTools.replace(out, "\"", "\\\"");
        return out;
    }

    public static function toLuaPath(value:String):String {
        return StringTools.replace(value, "\\", "/");
    }
}
