import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'parser.dart';
import 'renderer.dart';
import 'tools.dart' as tools;

class SpritemapExporter {
  Future<DescribeResult> describe(ProjectPaths paths) async {
    final logs = <String>[];
    var items = <AnimDef>[];

    if (tools.fileExists(paths.animsJson)) {
      items = _loadAnimsFromAnimlistJson(paths.animsJson);
      if (items.isNotEmpty) logs.add('Usando anims.json para poblar la lista.');
    }
    if (items.isEmpty && tools.fileExists(paths.animsXml)) {
      items = StfParser.parseAnimXml(paths.animsXml);
      if (items.isNotEmpty) logs.add('Usando anims.xml para poblar la lista.');
    }
    if (items.isEmpty && tools.fileExists(paths.animationJson)) {
      items = _loadAnimsFromAnimationJson(paths.animationJson);
      if (items.isNotEmpty) logs.add('Usando Animation.json para poblar la lista.');
    }
    if (items.isEmpty) logs.add('No encontré animaciones todavía.');

    final previewPath = tools.resolveAtlasPngPath(paths.atlasJson, paths.atlasPng);
    return DescribeResult(
      animations: items,
      previewPath: previewPath,
      outputDir: tools.resolveOutputDir(paths),
      log: tools.joinLines(logs),
    );
  }

  Future<ExportResult> export(ProjectPaths paths, List<AnimDef> selected) async {
    if (!tools.fileExists(paths.animationJson)) {
      return const ExportResult(ok: false, log: 'Falta Animation.json.');
    }
    if (!tools.fileExists(paths.atlasJson)) {
      return const ExportResult(ok: false, log: 'Falta spritemap1.json.');
    }
    selected = selected.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return const ExportResult(ok: false, log: 'Selecciona al menos una animación.');
    }

    late final dynamic animationData;
    late final dynamic atlasData;
    try {
      animationData = jsonDecode(tools.readFileStripBom(paths.animationJson));
    } catch (error) {
      return ExportResult(ok: false, log: 'error leyendo Animation.json: $error');
    }
    try {
      atlasData = jsonDecode(tools.readFileStripBom(paths.atlasJson));
    } catch (error) {
      return ExportResult(ok: false, log: 'error leyendo spritemap1.json: $error');
    }

    final atlasPngPath = tools.resolveAtlasPngPath(paths.atlasJson, paths.atlasPng);
    late final RgbaImage atlasImage;
    try {
      atlasImage = tools.readPng(atlasPngPath);
    } catch (error) {
      return ExportResult(ok: false, log: 'no pude cargar atlas PNG: $atlasPngPath ($error)');
    }

    final atlas = StfParser.parseAtlasData(atlasData);
    final symbols = _loadSymbols(animationData);
    final mainSymbol = _loadMainSymbol(animationData);
    final jobs = _buildJobs(selected, mainSymbol, symbols);
    final finalOutput = tools.resolveOutputDir(paths);
    final logs = <String>[];

    tools.deleteDirectory(finalOutput);
    tools.ensureDirectory(finalOutput);

    var progressCurrent = 0;
    var progressTotal = 0;
    for (final job in jobs) {
      progressTotal += _countValidFrames(job);
    }
    for (final job in jobs) {
      progressCurrent += _exportSymbol(job, finalOutput, symbols, atlas, atlasImage);
    }

    final zipPath = '$finalOutput.zip';
    try {
      _zipFolder(finalOutput, zipPath);
      logs.add('ZIP guardado en: $zipPath');
    } catch (error) {
      logs.add('Error al crear ZIP: $error');
    }
    logs.add('listo. salida en: $finalOutput');

    return ExportResult(
      ok: true,
      outputDir: finalOutput,
      zipPath: zipPath,
      filesWritten: progressCurrent,
      totalFrames: progressTotal,
      log: tools.joinLines(logs),
    );
  }

  List<AnimDef> _loadAnimsFromAnimlistJson(String path) {
    final out = <AnimDef>[];
    final data = jsonDecode(tools.readFileStripBom(path));
    for (final animation in tools.arrayField(data, 'animations')) {
      var animName = tools.stringField(animation, 'anim');
      var symbolName = tools.stringField(animation, 'name');
      if (tools.isBlank(animName)) animName = symbolName;
      if (tools.isBlank(symbolName)) symbolName = animName;
      if (tools.isBlank(animName) || tools.isBlank(symbolName)) continue;
      out.add(AnimDef(
        animName,
        symbolName,
        tools.asArray(tools.field(animation, 'indices')).map((value) => tools.intValue(value)).toList(),
      ));
    }
    return out;
  }

  List<AnimDef> _loadAnimsFromAnimationJson(String path) {
    final out = <AnimDef>[];
    final data = jsonDecode(tools.readFileStripBom(path));
    final main = _getMainAnimation(data);
    final mainName = _getAnimationName(main, 'main');
    final mainLabels = _loadMainFrameLabels(main, mainName);
    if (mainLabels.isNotEmpty) return mainLabels;
    if (!tools.isBlank(mainName)) out.add(AnimDef(mainName, mainName));
    for (final symbol in _getSymbolArray(data)) {
      final symbolName = _getSymbolName(symbol);
      if (!tools.isBlank(symbolName)) out.add(AnimDef(symbolName, symbolName));
    }
    return out;
  }

  Map<String, SymbolDef> _loadSymbols(dynamic data) {
    final symbols = <String, SymbolDef>{};
    for (final symbolJson in _getSymbolArray(data)) {
      final symbol = SymbolDef(name: _getSymbolName(symbolJson));
      final timelineJson = _getTimelineJson(symbolJson);
      if (timelineJson != null) symbol.timeline = StfParser.parseTimeline(timelineJson);
      if (!tools.isBlank(symbol.name)) symbols[symbol.name] = symbol;
    }
    return symbols;
  }

  SymbolDef _loadMainSymbol(dynamic data) {
    final animation = _getMainAnimation(data);
    final symbol = SymbolDef(name: _getAnimationName(animation, 'main'));
    final timelineJson = _getTimelineJson(animation);
    if (timelineJson != null) symbol.timeline = StfParser.parseTimeline(timelineJson);
    return symbol;
  }

  dynamic _getMainAnimation(dynamic data) => tools.field(data, 'AN') ?? tools.field(data, 'ANIMATION');

  String _getAnimationName(dynamic animation, String fallback) {
    if (animation == null) return fallback;
    final compact = tools.stringField(animation, 'N');
    if (!tools.isBlank(compact)) return compact;
    final verbose = tools.stringField(animation, 'SYMBOL_name');
    return tools.isBlank(verbose) ? fallback : verbose;
  }

  List<dynamic> _getSymbolArray(dynamic data) {
    final compact = tools.field(data, 'SD');
    final compactSymbols = tools.arrayField(compact, 'S');
    if (compactSymbols.isNotEmpty) return compactSymbols;
    final verbose = tools.field(data, 'SYMBOL_DICTIONARY');
    return tools.arrayField(verbose, 'Symbols');
  }

  String _getSymbolName(dynamic symbol) {
    final compact = tools.stringField(symbol, 'SN');
    if (!tools.isBlank(compact)) return compact;
    return tools.stringField(symbol, 'SYMBOL_name');
  }

  dynamic _getTimelineJson(dynamic owner) {
    if (owner == null) return null;
    return tools.field(owner, 'TL') ?? tools.field(owner, 'TIMELINE');
  }

  List<AnimDef> _loadMainFrameLabels(dynamic animation, String mainName) {
    final out = <AnimDef>[];
    final timeline = _getTimelineJson(animation);
    if (timeline == null || tools.isBlank(mainName)) return out;
    final layers = tools.arrayField(timeline, 'L');
    if (layers.isNotEmpty) {
      _collectFrameLabels(layers, 'FR', 'N', 'I', 'DU', mainName, out);
    } else {
      _collectFrameLabels(tools.arrayField(timeline, 'LAYERS'), 'Frames', 'name', 'index', 'duration', mainName, out);
    }
    return out;
  }

  void _collectFrameLabels(
    List<dynamic> layers,
    String framesField,
    String labelField,
    String startField,
    String durationField,
    String mainName,
    List<AnimDef> out,
  ) {
    final seen = <String>{};
    for (final layer in layers) {
      for (final frameJson in tools.arrayField(layer, framesField)) {
        final label = tools.stringField(frameJson, labelField);
        if (tools.isBlank(label)) continue;
        final start = tools.intField(frameJson, startField);
        final parsedDuration = tools.intField(frameJson, durationField, 1);
        final duration = parsedDuration <= 0 ? 1 : parsedDuration;
        final key = '$label:$start:$duration';
        if (!seen.add(key)) continue;
        out.add(AnimDef(label, mainName, [for (var frame = start; frame < start + duration; frame++) frame]));
      }
    }
  }

  List<ExportJob> _buildJobs(List<AnimDef> selected, SymbolDef mainSymbol, Map<String, SymbolDef> symbols) {
    final jobs = <ExportJob>[];
    for (final definition in selected) {
      if (definition.sourceAnim == mainSymbol.name) {
        jobs.add(ExportJob(mainSymbol, definition.name, definition.indices));
        continue;
      }
      final symbol = symbols[definition.sourceAnim];
      if (symbol != null) {
        jobs.add(ExportJob(symbol, definition.name, definition.indices));
        continue;
      }
      final fallback = symbols[definition.name];
      if (fallback != null) jobs.add(ExportJob(fallback, definition.sourceAnim, definition.indices));
    }
    return jobs;
  }

  int _countValidFrames(ExportJob job) {
    if (job.symbol.timeline.totalFrames <= 0) return 0;
    if (job.frames.isEmpty) return job.symbol.timeline.totalFrames;
    return job.frames.where((frame) => frame >= 0 && frame < job.symbol.timeline.totalFrames).length;
  }

  int _exportSymbol(
    ExportJob job,
    String outDir,
    Map<String, SymbolDef> symbols,
    Map<String, AtlasSpriteDef> atlas,
    RgbaImage atlasImage,
  ) {
    final symbol = job.symbol;
    if (symbol.timeline.totalFrames <= 0) return 0;
    final safeName = tools.sanitizeName(job.outName);
    final animDir = p.join(outDir, safeName);
    tools.ensureDirectory(animDir);
    final frameList = job.frames.isEmpty ? [for (var frame = 0; frame < symbol.timeline.totalFrames; frame++) frame] : List<int>.of(job.frames);
    final validFrames = frameList.where((frame) => frame >= 0 && frame < symbol.timeline.totalFrames).toList();

    final bounds = Bounds();
    final identity = Transform();
    for (final frame in validFrames) {
      Renderer.accumulateBoundsSymbol(symbol, frame, identity, symbols, atlas, bounds);
    }
    if (!bounds.initialized) return 0;

    final canvasWidth = (bounds.maxx - bounds.minx).ceil();
    final canvasHeight = (bounds.maxy - bounds.miny).ceil();
    if (canvasWidth <= 0 || canvasHeight <= 0) return 0;

    final offset = Transform(tx: -bounds.minx, ty: -bounds.miny);
    var written = 0;
    var frameOut = 0;
    for (final frame in validFrames) {
      final canvas = RgbaImage(canvasWidth, canvasHeight);
      Renderer.renderSymbol(symbol, frame, offset, symbols, atlas, atlasImage, canvas);
      final fileName = '${safeName}_${tools.formatFrameIndex(frameOut++)}.png';
      tools.writePng(canvas, p.join(animDir, fileName));
      written++;
    }
    return written;
  }

  void _zipFolder(String sourceDir, String zipPath) {
    if (File(zipPath).existsSync()) File(zipPath).deleteSync();
    ZipFileEncoder().zipDirectory(Directory(sourceDir), filename: zipPath);
  }
}
