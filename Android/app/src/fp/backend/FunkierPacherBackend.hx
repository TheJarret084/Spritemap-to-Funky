package fp.backend;

import android.AppModel.AnimationChoice;
import android.AppModel.ExportResult;
import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;
import android.gestor.GestorArchivosBackend;
import android.gestor.ImportadorMediaBackend;
import haxe.io.Path;
import stf.backend.Model.AtlasSpriteDef;
import stf.backend.Model.RgbaImage;
import stf.backend.Parser;
import stf.backend.Tools;
import stf.backend.ZipHelper;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class FunkierPacherBackend {
    public static function describe(paths:ProjectPaths):LoadResult {
        var logs:Array<String> = [];
        var dataPath = resolveDataPath(paths);
        var imagePath = resolveImagePath(paths);

        if (Tools.isBlank(imagePath)) logs.push("Falta la imagen del spritesheet.");
        if (Tools.isBlank(dataPath)) logs.push("Falta el archivo de datos del atlas.");
        if (!Tools.fileExists(imagePath)) logs.push("No encontré imagen: " + imagePath);
        if (!Tools.fileExists(dataPath)) logs.push("No encontré atlas data: " + dataPath);

        if (!Tools.fileExists(dataPath)) {
            logs.push("Salida por defecto: " + defaultOutputDir(paths));
            return new LoadResult([], Tools.joinLines(logs));
        }

        try {
            var frames = loadFrames(dataPath);
            var groups = groupFrames(frames);
            var choices:Array<AnimationChoice> = [];
            var names = sortedGroupNames(groups);
            for (name in names) {
                var group = groups.get(name);
                choices.push(new AnimationChoice(name, name, buildFrameIndices(group), true));
            }
            logs.push("Frames detectados: " + frames.length);
            logs.push("Animaciones detectadas: " + choices.length);
            logs.push("Salida por defecto: " + defaultOutputDir(paths));
            return new LoadResult(choices, Tools.joinLines(logs));
        } catch (error:Dynamic) {
            logs.push("No pude leer el atlas data: " + Std.string(error));
            return new LoadResult([], Tools.joinLines(logs));
        }
    }

    public static function export(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool = true):ExportResult {
        var logs:Array<String> = [];
        var imagePath = resolveImagePath(paths);
        var dataPath = resolveDataPath(paths);

        if (!Tools.fileExists(imagePath))
            return new ExportResult("Falta la imagen del spritesheet: " + imagePath);
        if (!Tools.fileExists(dataPath))
            return new ExportResult("Falta el archivo de datos del atlas: " + dataPath);

        var atlasImage:RgbaImage;
        try {
            atlasImage = RgbaImage.fromFile(imagePath);
        } catch (error:Dynamic) {
            return new ExportResult("No pude cargar la imagen: " + Std.string(error));
        }

        var frames:Array<FPFrame>;
        try {
            frames = loadFrames(dataPath);
        } catch (error:Dynamic) {
            return new ExportResult("No pude leer el atlas data: " + Std.string(error));
        }

        var groups = groupFrames(frames);
        var selected = selectedNames(choices);
        if (selected.length == 0) selected = sortedGroupNames(groups);
        if (selected.length == 0) return new ExportResult("No hay animaciones para exportar.");

        var outputDir = resolveOutputDir(paths);
        if (Tools.directoryExists(outputDir)) Tools.deleteDirectory(outputDir);
        Tools.ensureDirectory(outputDir);

        var written = 0;
        for (name in selected) {
            var group = groups.get(name);
            if (group == null || group.length == 0) continue;
            group.sort(compareFrames);

            var images:Array<RgbaImage> = [];
            for (frame in group) {
                var cropped = cropFrame(atlasImage, frame.sprite);
                if (cropped != null) images.push(cropped);
            }
            if (images.length == 0) continue;

            var strip = buildStrip(images);
            var outName = Tools.sanitizeName(name) + ".png";
            strip.writePng(Path.join([outputDir, outName]));
            written++;
        }

        if (written == 0) return new ExportResult("No se escribió ninguna tira PNG.", outputDir, 0);

        var zipPath = buildZipPath(paths, imagePath);
        try {
            clearFile(zipPath);
            ZipHelper.compressFolder(outputDir, zipPath);
            logs.push("Tiras guardadas en: " + outputDir);
            logs.push("ZIP guardado en: " + zipPath);
        } catch (error:Dynamic) {
            logs.push("Tiras guardadas en: " + outputDir);
            logs.push("Error al crear ZIP: " + Std.string(error));
        }

        return new ExportResult(Tools.joinLines(logs), outputDir, written, zipPath, zipPath, Path.withoutDirectory(zipPath));
    }

    public static function exportToMedia(paths:ProjectPaths, choices:Array<AnimationChoice>, exportFrames:Bool = true):ExportResult {
        return export(paths, choices, exportFrames);
    }

    static function loadFrames(dataPath:String):Array<FPFrame> {
        var atlas = Parser.parseAtlas(dataPath);
        var frames:Array<FPFrame> = [];
        for (name in atlas.keys()) {
            frames.push(new FPFrame(name, atlas.get(name)));
        }
        frames.sort(compareFrames);
        return frames;
    }

    static function groupFrames(frames:Array<FPFrame>):Map<String, Array<FPFrame>> {
        var groups = new Map<String, Array<FPFrame>>();
        if (frames == null) return groups;

        for (frame in frames) {
            var groupName = detectGroupName(frame.name);
            if (!groups.exists(groupName)) groups.set(groupName, []);
            groups.get(groupName).push(frame);
        }

        return groups;
    }

    static function detectGroupName(name:String):String {
        if (Tools.isBlank(name)) return "animation";
        var clean = name;
        var slash = clean.lastIndexOf("/");
        if (slash >= 0) clean = clean.substr(slash + 1);
        clean = Path.withoutExtension(clean);

        var trailingDigits = ~/^(.*?)([0-9]+)$/;
        if (trailingDigits.match(clean)) {
            var base = trailingDigits.matched(1);
            while (StringTools.endsWith(base, "_") || StringTools.endsWith(base, "-") || StringTools.endsWith(base, "."))
                base = base.substr(0, base.length - 1);
            return Tools.isBlank(base) ? "animation" : base;
        }

        return clean;
    }

    public static function frameNumber(name:String):Int {
        if (name == null) return 0;
        var trailingDigits = ~/([0-9]+)$/;
        if (trailingDigits.match(Path.withoutExtension(name))) {
            var parsed = Std.parseInt(trailingDigits.matched(1));
            return parsed == null ? 0 : parsed;
        }
        return 0;
    }

    static function sortedGroupNames(groups:Map<String, Array<FPFrame>>):Array<String> {
        var names:Array<String> = [];
        for (name in groups.keys()) names.push(name);
        names.sort(GestorArchivosBackend.compareStrings);
        return names;
    }

    static function selectedNames(choices:Array<AnimationChoice>):Array<String> {
        var out:Array<String> = [];
        if (choices == null) return out;
        for (choice in choices) {
            if (choice == null || !choice.selected || Tools.isBlank(choice.name)) continue;
            out.push(choice.name);
        }
        return out;
    }

    static function buildFrameIndices(group:Array<FPFrame>):Array<Int> {
        var out:Array<Int> = [];
        if (group == null) return out;
        group.sort(compareFrames);
        for (frame in group) out.push(frame.frameNumber);
        return out;
    }

    static function compareFrames(a:FPFrame, b:FPFrame):Int {
        if (a.frameNumber != b.frameNumber) return a.frameNumber < b.frameNumber ? -1 : 1;
        return GestorArchivosBackend.compareStrings(a.name, b.name);
    }

    static function cropFrame(atlas:RgbaImage, sprite:AtlasSpriteDef):RgbaImage {
        var drawWidth = sprite.rotated ? sprite.h : sprite.w;
        var drawHeight = sprite.rotated ? sprite.w : sprite.h;
        if (drawWidth <= 0 || drawHeight <= 0) return null;

        var out = RgbaImage.create(drawWidth, drawHeight);
        for (y in 0...drawHeight) {
            for (x in 0...drawWidth) {
                var sx:Int;
                var sy:Int;
                if (!sprite.rotated) {
                    sx = sprite.x + x;
                    sy = sprite.y + y;
                } else {
                    sx = sprite.x + (sprite.w - 1 - y);
                    sy = sprite.y + x;
                }
                if (sx < 0 || sy < 0 || sx >= atlas.width || sy >= atlas.height) continue;

                copyPixel(atlas, atlas.pixelOffset(sx, sy), out, out.pixelOffset(x, y));
            }
        }
        return out;
    }

    static function buildStrip(frames:Array<RgbaImage>):RgbaImage {
        var cellW = 1;
        var cellH = 1;
        for (frame in frames) {
            if (frame.width > cellW) cellW = frame.width;
            if (frame.height > cellH) cellH = frame.height;
        }

        var strip = RgbaImage.create(cellW * frames.length, cellH);
        for (i in 0...frames.length) {
            var frame = frames[i];
            var offsetX = Std.int(Math.floor((cellW - frame.width) * 0.5));
            var offsetY = Std.int(Math.floor((cellH - frame.height) * 0.5));
            var baseX = i * cellW + offsetX;

            for (y in 0...frame.height) {
                for (x in 0...frame.width) {
                    copyPixel(frame, frame.pixelOffset(x, y), strip, strip.pixelOffset(baseX + x, offsetY + y));
                }
            }
        }

        return strip;
    }

    static inline function copyPixel(src:RgbaImage, srcOffset:Int, dst:RgbaImage, dstOffset:Int):Void {
        dst.pixels.set(dstOffset, src.pixels.get(srcOffset));
        dst.pixels.set(dstOffset + 1, src.pixels.get(srcOffset + 1));
        dst.pixels.set(dstOffset + 2, src.pixels.get(srcOffset + 2));
        dst.pixels.set(dstOffset + 3, src.pixels.get(srcOffset + 3));
    }

    static function resolveImagePath(paths:ProjectPaths):String {
        return paths == null ? "" : paths.atlasPng;
    }

    static function resolveDataPath(paths:ProjectPaths):String {
        if (paths == null) return "";
        if (!Tools.isBlank(paths.animsXml)) return paths.animsXml;
        return paths.atlasJson;
    }

    static function resolveOutputDir(paths:ProjectPaths):String {
        if (paths != null && !Tools.isBlank(paths.outputDir)) return paths.outputDir;
        return defaultOutputDir(paths);
    }

    static function defaultOutputDir(paths:ProjectPaths):String {
        ImportadorMediaBackend.ensureMediaDirectories();
        var base = "spritesheet";
        if (paths != null) {
            if (!Tools.isBlank(paths.atlasPng)) base = Path.withoutExtension(Path.withoutDirectory(paths.atlasPng));
            else if (!Tools.isBlank(paths.animsXml)) base = Path.withoutExtension(Path.withoutDirectory(paths.animsXml));
        }
        return Path.join([ImportadorMediaBackend.getMediaProcessedDir(), "funkier-pacher", Tools.sanitizeName(base)]);
    }

    static function buildZipPath(paths:ProjectPaths, imagePath:String):String {
        ImportadorMediaBackend.ensureMediaDirectories();
        var base = !Tools.isBlank(imagePath) ? Path.withoutExtension(Path.withoutDirectory(imagePath)) : "spritesheet";
        var zipName = "TJ_" + Tools.sanitizeName(base) + ".zip";
        return Path.join([ImportadorMediaBackend.getMediaExportsDir(), zipName]);
    }

    static function clearFile(path:String):Void {
        #if sys
        if (!Tools.isBlank(path) && FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
            FileSystem.deleteFile(path);
        }
        #end
    }
}

class FPFrame {
    public var name:String;
    public var sprite:AtlasSpriteDef;
    public var frameNumber:Int;

    public function new(name:String, sprite:AtlasSpriteDef) {
        this.name = name;
        this.sprite = sprite;
        this.frameNumber = FunkierPacherBackend.frameNumber(name);
    }
}
