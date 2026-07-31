package stf.backend;

import stf.backend.Model.AnimDef;
import stf.backend.Model.AtlasSpriteDef;
import stf.backend.Model.Bounds;
import stf.backend.Model.ExportJob;
import stf.backend.Model.RgbaImage;
import stf.backend.Model.SymbolDef;
import stf.backend.Model.Transform;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Exporter {
    public static function describeRequest(request:Dynamic):Dynamic {
        var logs:Array<String> = [];

        var animationJson = Tools.stringField(request, "animationJson", "");
        var atlasJson = Tools.stringField(request, "atlasJson", "");
        var atlasPng = Tools.stringField(request, "atlasPng", "");
        var animsXml = Tools.stringField(request, "animsXml", "");
        var animsJson = Tools.stringField(request, "animsJson", "");
        var outputDir = Tools.stringField(request, "outputDir", "");

        var items:Array<AnimDef> = [];
        if (Tools.fileExists(animsJson)) {
            items = loadAnimsFromAnimlistJson(animsJson);
            if (items.length > 0) logs.push("Usando anims.json para poblar la lista.");
        }

        if (items.length == 0 && Tools.fileExists(animsXml)) {
            items = Parser.parseAnimXml(animsXml);
            if (items.length > 0) logs.push("Usando anims.xml para poblar la lista.");
        }

        if (items.length == 0 && Tools.fileExists(animationJson)) {
            items = loadAnimsFromAnimationJson(animationJson);
            if (items.length > 0) logs.push("Usando Animation.json para poblar la lista.");
        }

        var animations:Array<Dynamic> = [];
        for (item in items) {
            animations.push({
                name: item.name,
                source: item.sourceAnim,
                indices: item.indices
            });
        }

        if (items.length == 0) logs.push("No encontré animaciones todavía.");

        return {
            ok: true,
            previewPath: Tools.resolvePreviewPath(atlasJson, atlasPng),
            outputDir: Tools.resolveOutputDir(animationJson, animsXml, animsJson, outputDir),
            animations: animations,
            log: Tools.joinLines(logs)
        };
    }

    public static function exportRequest(request:Dynamic):Dynamic {
        var animationJson = Tools.stringField(request, "animationJson", "");
        var atlasJson = Tools.stringField(request, "atlasJson", "");
        var atlasPng = Tools.stringField(request, "atlasPng", "");
        var animsXml = Tools.stringField(request, "animsXml", "");
        var animsJson = Tools.stringField(request, "animsJson", "");
        var outputDir = Tools.stringField(request, "outputDir", "");

        if (!Tools.fileExists(animationJson))
            return Tools.makeError("Falta Animation.json.");
        if (!Tools.fileExists(atlasJson))
            return Tools.makeError("Falta spritemap1.json.");

        var selected = loadSelectedItems(request);
        if (selected.length == 0)
            return Tools.makeError("Selecciona al menos una animación.");

        var animationData:Dynamic;
        try {
            animationData = Json.parse(Tools.readFileStripBom(animationJson));
        } catch (error:Dynamic) {
            return Tools.makeError("error leyendo Animation.json: " + Std.string(error));
        }

        var atlasData:Dynamic;
        try {
            atlasData = Json.parse(Tools.readFileStripBom(atlasJson));
        } catch (error:Dynamic) {
            return Tools.makeError("error leyendo spritemap1.json: " + Std.string(error));
        }

        var atlasPngPath = Tools.resolveAtlasPngPath(atlasJson, atlasPng);
        var atlasImage:RgbaImage;
        try {
            atlasImage = RgbaImage.fromFile(atlasPngPath);
        } catch (error:Dynamic) {
            return Tools.makeError("no pude cargar atlas PNG: " + atlasPngPath + " (" + Std.string(error) + ")");
        }

        var atlas = loadAtlasMap(atlasData);
        var symbols = loadSymbols(animationData);
        var mainSymbol = loadMainSymbol(animationData);
        var jobs = buildJobs(selected, mainSymbol, symbols);
        var finalOutput = Tools.resolveOutputDir(animationJson, animsXml, animsJson, outputDir);
        var logs:Array<String> = [];

        if (Tools.directoryExists(finalOutput))
            Tools.deleteDirectory(finalOutput);
        Tools.ensureDirectory(finalOutput);

        var progressCurrent = 0;
        var progressTotal = 0;
        for (job in jobs) progressTotal += countValidFrames(job);
        for (job in jobs) progressCurrent += exportSymbol(job, finalOutput, symbols, atlas, atlasImage, logs);

        // Comprimir output en ZIP
        var zipPath = finalOutput + ".zip";
        try {
            ZipHelper.compressFolder(finalOutput, zipPath);
            logs.push("ZIP guardado en: " + zipPath);
        } catch (error:Dynamic) {
            logs.push("Error al crear ZIP: " + Std.string(error));
        }

        logs.push("listo. salida en: " + finalOutput);

        return {
            ok: true,
            outputDir: finalOutput,
            zipPath: zipPath,
            filesWritten: progressCurrent,
            totalFrames: progressTotal,
            errorCode: 0,
            log: Tools.joinLines(logs)
        };
    }

    static function loadAnimsFromAnimlistJson(path:String):Array<AnimDef> {
        var out:Array<AnimDef> = [];
        var data = Json.parse(Tools.readFileStripBom(path));

        for (animation in Tools.arrayField(data, "animations")) {
            var animName = Tools.stringField(animation, "anim", "");
            var symbolName = Tools.stringField(animation, "name", "");

            if (Tools.isBlank(animName)) animName = symbolName;
            if (Tools.isBlank(symbolName)) symbolName = animName;
            if (Tools.isBlank(animName) || Tools.isBlank(symbolName)) continue;

            var indices:Array<Int> = [];
            for (value in Tools.asArray(Tools.field(animation, "indices"))) {
                if (value != null) indices.push(Std.int(value));
            }

            out.push(new AnimDef(animName, symbolName, indices));
        }

        return out;
    }

    static function loadAnimsFromAnimationJson(path:String):Array<AnimDef> {
        var out:Array<AnimDef> = [];
        var data = Json.parse(Tools.readFileStripBom(path));

        var main = getMainAnimation(data);
        var mainName = getAnimationName(main, "main");
        var mainLabels = loadMainFrameLabels(main, mainName);

        if (mainLabels.length > 0) {
            return mainLabels;
        }

        if (!Tools.isBlank(mainName)) {
            out.push(new AnimDef(mainName, mainName, []));
        }

        for (symbol in getSymbolArray(data)) {
            var symbolName = getSymbolName(symbol);
            if (!Tools.isBlank(symbolName))
                out.push(new AnimDef(symbolName, symbolName, []));
        }

        return out;
    }

    static function loadSelectedItems(request:Dynamic):Array<AnimDef> {
        var out:Array<AnimDef> = [];
        for (item in Tools.arrayField(request, "selected")) {
            var name = Tools.stringField(item, "name", "");
            var source = Tools.stringField(item, "source", "");
            if (Tools.isBlank(name) || Tools.isBlank(source)) continue;

            var indices:Array<Int> = [];
            for (entry in Tools.asArray(Tools.field(item, "indices"))) {
                if (entry != null) indices.push(Std.int(entry));
            }

            out.push(new AnimDef(name, source, indices));
        }

        return out;
    }

    static function loadAtlasMap(data:Dynamic):Map<String, AtlasSpriteDef> {
        var atlas = new Map<String, AtlasSpriteDef>();
        var atlasRoot = Tools.field(data, "ATLAS");

        for (entry in Tools.arrayField(atlasRoot, "SPRITES")) {
            var spriteJson = Tools.field(entry, "SPRITE");
            if (spriteJson == null) continue;

            var sprite = new AtlasSpriteDef();
            sprite.x = Tools.intField(spriteJson, "x", 0);
            sprite.y = Tools.intField(spriteJson, "y", 0);
            sprite.w = Tools.intField(spriteJson, "w", 0);
            sprite.h = Tools.intField(spriteJson, "h", 0);
            sprite.rotated = Tools.boolField(spriteJson, "rotated", false);

            var name = Tools.stringField(spriteJson, "name", "");
            if (!Tools.isBlank(name)) atlas.set(name, sprite);
        }

        return atlas;
    }

    static function loadSymbols(data:Dynamic):Map<String, SymbolDef> {
        var symbols = new Map<String, SymbolDef>();

        for (symbolJson in getSymbolArray(data)) {
            var symbol = new SymbolDef();
            symbol.name = getSymbolName(symbolJson);

            var timelineJson = getTimelineJson(symbolJson);
            if (timelineJson != null)
                symbol.timeline = Parser.parseTimeline(timelineJson);

            if (!Tools.isBlank(symbol.name))
                symbols.set(symbol.name, symbol);
        }

        return symbols;
    }

    static function loadMainSymbol(data:Dynamic):SymbolDef {
        var symbol = new SymbolDef();
        var animation = getMainAnimation(data);

        symbol.name = getAnimationName(animation, "main");

        var timelineJson = getTimelineJson(animation);
        if (timelineJson != null)
            symbol.timeline = Parser.parseTimeline(timelineJson);

        return symbol;
    }

    static function getMainAnimation(data:Dynamic):Dynamic {
        var animation = Tools.field(data, "AN");
        return animation != null ? animation : Tools.field(data, "ANIMATION");
    }

    static function getAnimationName(animation:Dynamic, fallback:String):String {
        if (animation == null) return fallback;

        var compact = Tools.stringField(animation, "N", "");
        if (!Tools.isBlank(compact)) return compact;

        var verbose = Tools.stringField(animation, "SYMBOL_name", "");
        return Tools.isBlank(verbose) ? fallback : verbose;
    }

    static function getSymbolArray(data:Dynamic):Array<Dynamic> {
        var compact = Tools.field(data, "SD");
        var compactSymbols = Tools.arrayField(compact, "S");
        if (compactSymbols.length > 0) return compactSymbols;

        var verbose = Tools.field(data, "SYMBOL_DICTIONARY");
        return Tools.arrayField(verbose, "Symbols");
    }

    static function getSymbolName(symbol:Dynamic):String {
        var compact = Tools.stringField(symbol, "SN", "");
        if (!Tools.isBlank(compact)) return compact;
        return Tools.stringField(symbol, "SYMBOL_name", "");
    }

    static function getTimelineJson(owner:Dynamic):Dynamic {
        if (owner == null) return null;

        var compact = Tools.field(owner, "TL");
        if (compact != null) return compact;

        return Tools.field(owner, "TIMELINE");
    }

    static function loadMainFrameLabels(animation:Dynamic, mainName:String):Array<AnimDef> {
        var out:Array<AnimDef> = [];
        var timeline = getTimelineJson(animation);
        if (timeline == null || Tools.isBlank(mainName)) return out;

        var layers = Tools.arrayField(timeline, "L");
        if (layers.length > 0) {
            collectFrameLabels(layers, "FR", "N", "I", "DU", mainName, out);
            return out;
        }

        var verboseLayers = Tools.arrayField(timeline, "LAYERS");
        collectFrameLabels(verboseLayers, "Frames", "name", "index", "duration", mainName, out);
        return out;
    }

    static function collectFrameLabels(
        layers:Array<Dynamic>,
        framesField:String,
        labelField:String,
        startField:String,
        durationField:String,
        mainName:String,
        out:Array<AnimDef>
    ):Void {
        var seen = new Map<String, Bool>();

        for (layer in layers) {
            for (frameJson in Tools.arrayField(layer, framesField)) {
                var label = Tools.stringField(frameJson, labelField, "");
                if (Tools.isBlank(label)) continue;

                var start = Tools.intField(frameJson, startField, 0);
                var duration = Tools.intField(frameJson, durationField, 1);
                if (duration <= 0) duration = 1;

                var key = label + ":" + start + ":" + duration;
                if (seen.exists(key)) continue;
                seen.set(key, true);

                var indices:Array<Int> = [];
                for (frame in start...start + duration) indices.push(frame);
                out.push(new AnimDef(label, mainName, indices));
            }
        }
    }

    static function buildJobs(selected:Array<AnimDef>, mainSymbol:SymbolDef, symbols:Map<String, SymbolDef>):Array<ExportJob> {
        var jobs:Array<ExportJob> = [];

        for (definition in selected) {
            if (definition.sourceAnim == mainSymbol.name) {
                jobs.push(new ExportJob(mainSymbol, definition.name, definition.indices));
                continue;
            }

            var symbol = symbols.get(definition.sourceAnim);
            if (symbol != null) {
                jobs.push(new ExportJob(symbol, definition.name, definition.indices));
                continue;
            }

            var fallback = symbols.get(definition.name);
            if (fallback != null)
                jobs.push(new ExportJob(fallback, definition.sourceAnim, definition.indices));
        }

        return jobs;
    }

    static function countValidFrames(job:ExportJob):Int {
        if (job.symbol.timeline.totalFrames <= 0) return 0;
        if (job.frames.length == 0) return job.symbol.timeline.totalFrames;

        var count = 0;
        for (frame in job.frames) {
            if (frame >= 0 && frame < job.symbol.timeline.totalFrames) count++;
        }
        return count;
    }

    static function exportSymbol(
        job:ExportJob,
        outDir:String,
        symbols:Map<String, SymbolDef>,
        atlas:Map<String, AtlasSpriteDef>,
        atlasImage:RgbaImage,
        logs:Array<String>
    ):Int {
        var symbol = job.symbol;
        if (symbol.timeline.totalFrames <= 0) return 0;

        var safeName = Tools.sanitizeName(job.outName);
        var animDir = Path.join([outDir, safeName]);
        Tools.ensureDirectory(animDir);

        var frameList:Array<Int> = [];
        if (job.frames.length == 0) {
            for (frame in 0...symbol.timeline.totalFrames) frameList.push(frame);
        } else {
            frameList = job.frames.copy();
        }

        var validFrames:Array<Int> = [];
        for (frame in frameList) {
            if (frame >= 0 && frame < symbol.timeline.totalFrames)
                validFrames.push(frame);
        }

        var bounds = new Bounds();
        var identity = new Transform();
        for (frame in validFrames)
            Renderer.accumulateBoundsSymbol(symbol, frame, identity, symbols, atlas, bounds);

        if (!bounds.initialized) return 0;

        var canvasWidth = Std.int(Math.ceil(bounds.maxx - bounds.minx));
        var canvasHeight = Std.int(Math.ceil(bounds.maxy - bounds.miny));
        if (canvasWidth <= 0 || canvasHeight <= 0) return 0;

        var offset = new Transform();
        offset.tx = -bounds.minx;
        offset.ty = -bounds.miny;

        var written = 0;
        var frameOut = 0;
        for (frame in validFrames) {
            var frameIndex = frameOut++;
            var canvas = RgbaImage.create(canvasWidth, canvasHeight);
            Renderer.renderSymbol(symbol, frame, offset, symbols, atlas, atlasImage, canvas);

            var fileName = safeName + "_" + Tools.formatFrameIndex(frameIndex) + ".png";
            canvas.writePng(Path.join([animDir, fileName]));
            written++;
        }

        return written;
    }
}
