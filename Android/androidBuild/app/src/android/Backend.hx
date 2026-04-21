package android;

import backend.Api;
import backend.Tools;
import haxe.Json;
import haxe.ds.List;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Writer;
import android.AppModel.AnimationChoice;
import android.AppModel.ExportResult;
import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class Backend {
    public static function createDefaultPaths():ProjectPaths {
        var paths = new ProjectPaths();
        paths.outputDir = getProcessingOutputDir();
        return paths;
    }

    public static function resetWorkspace():Void {
        #if android
        AndroidFilePicker.clearWorkspace();
        #end
    }

    public static function cleanupAfterSave():Void {
        resetWorkspace();
    }

    public static function getWorkspaceRoot():String {
        #if android
        var fromBridge = AndroidFilePicker.getWorkspaceRoot();
        if (!isBlank(fromBridge)) return fromBridge;
        #end

        #if sys
        return Path.join([Sys.getCwd(), "android-workspace"]);
        #else
        return "android-workspace";
        #end
    }

    /** Directorio temporal para frames procesados — siempre en storage interno */
    public static function getProcessingOutputDir():String {
        #if android
        var dir = AppConfig.getProcessedDir();
        Tools.ensureDirectory(dir);
        return dir;
        #else
        return Path.join([getWorkspaceRoot(), "processed"]);
        #end
    }

    /** Directorio de exports finales — en Android/media para que el usuario lo vea */
    static function getExportsDir():String {
        #if android
        var dir = AppConfig.getExportsDir();
        Tools.ensureDirectory(dir);
        return dir;
        #else
        return Path.join([getWorkspaceRoot(), "exports"]);
        #end
    }

    public static function loadProject(paths:ProjectPaths):LoadResult {
        var response = callDescribe(normalizePaths(paths));
        return new LoadResult(
            parseAnimations(field(response, "animations")),
            stringField(response, "log")
        );
    }

    public static function exportProject(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool):ExportResult {
        var normalizedPaths = normalizePaths(paths);
        normalizedPaths.outputDir = getProcessingOutputDir();
        clearDirectory(normalizedPaths.outputDir);

        var request:Dynamic = buildBaseRequest(normalizedPaths);
        Reflect.setField(request, "selected", toSelectionPayload(choices));
        Reflect.setField(request, "exportFrames", exportFrames);
        Reflect.setField(request, "exportAse", false);
        Reflect.setField(request, "asepritePath", "aseprite");

        var response = parseJsonResponse(Api.exportProject(Json.stringify(request)));
        var result = new ExportResult(
            stringField(response, "log"),
            stringField(response, "outputDir"),
            intField(response, "filesWritten", 0)
        );

        if (result.filesWritten > 0) {
            var archiveName = buildArchiveName(normalizedPaths);
            var archivePath = Path.join([getExportsDir(), archiveName]);
            clearFile(archivePath);
            zipDirectory(result.outputDir, archivePath);
            result.archiveName = archiveName;
            result.archivePath = archivePath;
        }

        return result;
    }

    static function callDescribe(paths:ProjectPaths):Dynamic {
        return parseJsonResponse(Api.describeProject(Json.stringify(buildBaseRequest(paths))));
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

    static function normalizePaths(paths:ProjectPaths):ProjectPaths {
        var normalized = paths != null ? paths.clone() : new ProjectPaths();
        if (isBlank(normalized.outputDir)) normalized.outputDir = getProcessingOutputDir();
        return normalized;
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

    static function buildArchiveName(paths:ProjectPaths):String {
        var base = "";

        if (!isBlank(paths.animsJson)) {
            base = Path.withoutExtension(Path.withoutDirectory(paths.animsJson));
        } else if (!isBlank(paths.animsXml)) {
            base = Path.withoutExtension(Path.withoutDirectory(paths.animsXml));
        } else if (!isBlank(paths.animationJson)) {
            base = Path.withoutExtension(Path.withoutDirectory(paths.animationJson));
        }

        if (isBlank(base)) base = "spritemap-to-funky";
        return Tools.sanitizeName(base) + ".zip";
    }

    static function zipDirectory(sourceDir:String, archivePath:String):Void {
        #if sys
        Tools.ensureDirectory(Path.directory(archivePath));

        var entries = new List<Entry>();
        var files = collectFiles(sourceDir);
        for (path in files) {
            var bytes = File.getBytes(path);
            var relative = toZipPath(makeRelativePath(sourceDir, path));
            var entry:Entry = {
                fileName: relative,
                fileSize: bytes.length,
                fileTime: Date.now(),
                compressed: false,
                dataSize: bytes.length,
                data: bytes,
                crc32: null
            };
            haxe.zip.Tools.compress(entry, 9);
            entries.add(entry);
        }

        var output = File.write(archivePath, true);
        new Writer(output).write(entries);
        output.close();
        #end
    }

    static function collectFiles(path:String):Array<String> {
        #if sys
        var results:Array<String> = [];
        if (!FileSystem.exists(path)) return results;

        if (!FileSystem.isDirectory(path)) {
            results.push(path);
            return results;
        }

        for (name in FileSystem.readDirectory(path)) {
            var child = Path.join([path, name]);
            if (FileSystem.isDirectory(child)) {
                results = results.concat(collectFiles(child));
            } else {
                results.push(child);
            }
        }

        return results;
        #else
        return [];
        #end
    }

    static function makeRelativePath(root:String, path:String):String {
        var normalizedRoot = StringTools.replace(Path.normalize(root), "\\", "/");
        var normalizedPath = StringTools.replace(Path.normalize(path), "\\", "/");
        var prefix = normalizedRoot;
        if (!StringTools.endsWith(prefix, "/")) prefix += "/";
        return StringTools.startsWith(normalizedPath, prefix) ? normalizedPath.substr(prefix.length) : normalizedPath;
    }

    static function toZipPath(value:String):String {
        return StringTools.replace(value, "\\", "/");
    }

    static function clearDirectory(path:String):Void {
        #if sys
        if (isBlank(path)) return;
        if (FileSystem.exists(path)) deleteRecursively(path);
        Tools.ensureDirectory(path);
        #end
    }

    static function clearFile(path:String):Void {
        #if sys
        if (!isBlank(path) && FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
            FileSystem.deleteFile(path);
        }
        #end
    }

    static function deleteRecursively(path:String):Void {
        #if sys
        if (!FileSystem.exists(path)) return;
        if (!FileSystem.isDirectory(path)) {
            FileSystem.deleteFile(path);
            return;
        }

        for (name in FileSystem.readDirectory(path)) {
            deleteRecursively(Path.join([path, name]));
        }

        FileSystem.deleteDirectory(path);
        #end
    }
}