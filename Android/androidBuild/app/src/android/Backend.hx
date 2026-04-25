package android;

import android.gestor.GestorArchivosBackend;
import android.gestor.ImportadorMediaBackend;
import android.api.Api;
import backend.Tools;
import haxe.Json;
import haxe.io.Path;
import android.AppModel.AnimationChoice;
import android.AppModel.ExportResult;
import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;

#if sys
import sys.FileSystem;
#end

class Backend {
    public static function createDefaultPaths():ProjectPaths {
        var paths = new ProjectPaths();
        paths.outputDir = getProcessingOutputDir();
        return paths;
    }

    public static function resetWorkspace():Void {
        GestorArchivosBackend.resetWorkspace();
    }

    public static function cleanupAfterSave():Void {
        GestorArchivosBackend.cleanupAfterSave();
    }

    public static function getWorkspaceRoot():String {
        return GestorArchivosBackend.getWorkspaceRoot();
    }

    /** Directorio temporal para frames procesados — siempre en storage interno */
    public static function getProcessingOutputDir():String {
        return GestorArchivosBackend.getProcessingDir();
    }

    public static function loadProject(paths:ProjectPaths):LoadResult {
        var response = callDescribe(normalizePaths(paths));
        return new LoadResult(
            parseAnimations(field(response, "animations")),
            stringField(response, "log")
        );
    }

    public static function exportProject(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool):ExportResult {
        return exportProjectInternal(paths, choices, exportFrames, getProcessingOutputDir(), true);
    }

    public static function exportProjectToMedia(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool):ExportResult {
        return exportProjectInternal(
            paths,
            choices,
            exportFrames,
            ImportadorMediaBackend.buildProcessedOutputDir(paths),
            false
        );
    }

    static function exportProjectInternal(
        paths:ProjectPaths,
        choices:Array<AnimationChoice>,
        exportFrames:Bool,
        targetOutputDir:String,
        stageZip:Bool
    ):ExportResult {
        var normalizedPaths = normalizePaths(paths);
        normalizedPaths.outputDir = isBlank(targetOutputDir) ? getProcessingOutputDir() : targetOutputDir;
        clearDirectory(normalizedPaths.outputDir);

        var request:Dynamic = buildBaseRequest(normalizedPaths);
        Reflect.setField(request, "selected", toSelectionPayload(choices));
        Reflect.setField(request, "exportFrames", exportFrames);

        var response = parseJsonResponse(Api.exportProject(Json.stringify(request)));
        var result = new ExportResult(
            stringField(response, "log"),
            stringField(response, "outputDir"),
            intField(response, "filesWritten", 0),
            stringField(response, "zipPath")
        );

        if (result.filesWritten > 0 && !isBlank(result.zipPath)) {
            var archiveName = buildArchiveName(normalizedPaths);
            result.archiveName = archiveName;
            result.archivePath = stageZip
                ? GestorArchivosBackend.stageExportZip(result.zipPath, archiveName)
                : result.zipPath;
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

    static function clearDirectory(path:String):Void {
        #if sys
        if (isBlank(path)) return;
        if (FileSystem.exists(path)) deleteRecursively(path);
        Tools.ensureDirectory(path);
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
