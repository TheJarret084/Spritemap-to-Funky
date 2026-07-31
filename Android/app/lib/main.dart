import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'backend/funkier_pacher.dart';
import 'backend/models.dart';
import 'backend/spritemap_exporter.dart';
import 'backend/tools.dart' as tools;

void main() {
  runApp(const SpritemapToFunkyApp());
}

class SpritemapToFunkyApp extends StatelessWidget {
  const SpritemapToFunkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spritemap to Funky',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff14b8a6),
          brightness: Brightness.dark,
          surface: const Color(0xff171b20),
        ),
        scaffoldBackgroundColor: const Color(0xff101418),
        fontFamily: 'Terminus',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _spritemapExporter = SpritemapExporter();
  final _funkierExporter = FunkierPacherExporter();
  var _paths = const ProjectPaths();
  var _tab = 0;
  var _busy = false;
  var _log = 'Esperando archivos.';
  var _previewPath = '';
  var _stfAnimations = <AnimDef>[];
  var _fpAnimations = <AnimDef>[];

  List<AnimDef> get _currentAnimations => _tab == 0 ? _stfAnimations : _fpAnimations;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spritemap to Funky'),
        actions: [
          IconButton(
            tooltip: 'Analizar',
            onPressed: _busy ? null : _analyze,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Exportar',
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _AccentLine(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.auto_awesome_motion), label: Text('Spritemap')),
                  ButtonSegment(value: 1, icon: Icon(Icons.grid_view), label: Text('Funkier')),
                ],
                selected: {_tab},
                onSelectionChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _tab = value.first;
                          _previewPath = _paths.atlasPng;
                        });
                      },
              ),
            ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 390, child: SingleChildScrollView(child: _projectPane())),
                        Expanded(child: SingleChildScrollView(child: _animationPane())),
                        SizedBox(width: 340, child: SingleChildScrollView(child: _consolePane())),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        _projectPane(),
                        _animationPane(minHeight: 360),
                        _consolePane(minHeight: 260),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        busy: _busy,
        zipPath: _lastZipFromLog(),
        onAnalyze: _analyze,
        onExport: _export,
        onShare: _shareZip,
      ),
    );
  }

  Widget _projectPane() {
    return _Panel(
      title: 'Proyecto',
      icon: Icons.folder_open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tab == 0) ...[
            _FileRow(
              label: 'Animation.json',
              value: _paths.animationJson,
              icon: Icons.description_outlined,
              onPick: () => _pickFile(['json'], (path) => _paths = _paths.copyWith(animationJson: path)),
            ),
            _FileRow(
              label: 'spritemap1.json',
              value: _paths.atlasJson,
              icon: Icons.data_object,
              onPick: () => _pickFile(['json'], (path) => _paths = _paths.copyWith(atlasJson: path)),
            ),
            _FileRow(
              label: 'spritemap1.png',
              value: _paths.atlasPng,
              icon: Icons.image_outlined,
              onPick: () => _pickFile(['png'], (path) => _paths = _paths.copyWith(atlasPng: path)),
            ),
            _FileRow(
              label: 'anims.xml',
              value: _paths.animsXml,
              icon: Icons.code,
              onPick: () => _pickFile(['xml'], (path) => _paths = _paths.copyWith(animsXml: path)),
            ),
            _FileRow(
              label: 'anims.json',
              value: _paths.animsJson,
              icon: Icons.list_alt,
              onPick: () => _pickFile(['json'], (path) => _paths = _paths.copyWith(animsJson: path)),
            ),
          ] else ...[
            _FileRow(
              label: 'spritesheet.png',
              value: _paths.atlasPng,
              icon: Icons.image_outlined,
              onPick: () => _pickFile(['png'], (path) => _paths = _paths.copyWith(atlasPng: path)),
            ),
            _FileRow(
              label: 'atlas data',
              value: _paths.atlasJson,
              icon: Icons.data_object,
              onPick: () => _pickFile(['json', 'xml'], (path) => _paths = _paths.copyWith(atlasJson: path)),
            ),
          ],
          _FileRow(
            label: 'salida',
            value: _paths.outputDir,
            icon: Icons.drive_folder_upload_outlined,
            onPick: _pickOutputDir,
          ),
          const SizedBox(height: 12),
          if (tools.fileExists(_previewPath))
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                color: const Color(0xff0b0f14),
                alignment: Alignment.center,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 8,
                  child: Image.file(File(_previewPath), filterQuality: FilterQuality.none),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _animationPane({double? minHeight}) {
    final selected = _currentAnimations.where((item) => item.selected).length;
    final listHeight = minHeight ?? 420;
    return _Panel(
      title: 'Animaciones',
      icon: Icons.animation,
      minHeight: minHeight,
      actions: [
        IconButton(
          tooltip: 'Seleccionar todo',
          onPressed: _busy ? null : () => _setAll(true),
          icon: const Icon(Icons.select_all),
        ),
        IconButton(
          tooltip: 'Limpiar selección',
          onPressed: _busy ? null : () => _setAll(false),
          icon: const Icon(Icons.deselect),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$selected/${_currentAnimations.length} seleccionadas', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: listHeight,
            child: _currentAnimations.isEmpty
                ? const Center(child: Text('Sin animaciones'))
                : ListView.separated(
                itemCount: _currentAnimations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _currentAnimations[index];
                  return CheckboxListTile(
                    value: item.selected,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      item.indices.isEmpty ? item.sourceAnim : '${item.sourceAnim}  [${item.indices.join(', ')}]',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => item.selected = value ?? false);
                          },
                  );
                },
              ),
          ),
        ],
      ),
    );
  }

  Widget _consolePane({double? minHeight}) {
    return _Panel(
      title: 'Consola',
      icon: Icons.terminal,
      minHeight: minHeight,
      child: SizedBox(
        height: minHeight ?? 420,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff0b0f14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xff27313a)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _log,
              style: const TextStyle(fontFamily: 'DepartureMono', fontSize: 12.5, height: 1.25),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile(List<String> extensions, void Function(String path) apply) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: extensions);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      apply(path);
      if (extensions.contains('png')) _previewPath = path;
    });
  }

  Future<void> _pickOutputDir() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    setState(() => _paths = _paths.copyWith(outputDir: path));
  }

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _log = 'Analizando...';
    });
    try {
      final result = _tab == 0 ? await _spritemapExporter.describe(_paths) : await _funkierExporter.describe(_paths);
      setState(() {
        if (_tab == 0) {
          _stfAnimations = result.animations;
        } else {
          _fpAnimations = result.animations;
        }
        _previewPath = result.previewPath;
        _log = result.log.isEmpty ? 'Listo. Salida: ${result.outputDir}' : '${result.log}\nSalida: ${result.outputDir}';
      });
    } catch (error) {
      setState(() => _log = 'Error: $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_currentAnimations.isEmpty) await _analyze();
    setState(() {
      _busy = true;
      _log = 'Exportando...';
    });
    try {
      final result = _tab == 0
          ? await _spritemapExporter.export(_paths, _stfAnimations)
          : await _funkierExporter.export(_paths, _fpAnimations);
      setState(() {
        _log = result.log;
        if (result.zipPath.isNotEmpty) _log = '${result.log}\nzipPath=${result.zipPath}';
      });
    } catch (error) {
      setState(() => _log = 'Error: $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _setAll(bool selected) {
    setState(() {
      for (final item in _currentAnimations) {
        item.selected = selected;
      }
    });
  }

  String _lastZipFromLog() {
    final match = RegExp(r'zipPath=(.+)$', multiLine: true).firstMatch(_log);
    return match?.group(1)?.trim() ?? '';
  }

  Future<void> _shareZip() async {
    final zipPath = _lastZipFromLog();
    if (!tools.fileExists(zipPath)) return;
    await Share.shareXFiles([XFile(zipPath)], text: p.basename(zipPath));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.actions = const [],
    this.minHeight,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff171b20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff27313a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ...actions,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  value.isEmpty ? 'sin seleccionar' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xff94a3b8)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: label,
            onPressed: onPick,
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.zipPath,
    required this.onAnalyze,
    required this.onExport,
    required this.onShare,
  });

  final bool busy;
  final String zipPath;
  final VoidCallback onAnalyze;
  final VoidCallback onExport;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xff171b20),
          border: Border(top: BorderSide(color: Color(0xff27313a))),
        ),
        child: Row(
          children: [
            if (busy)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.check_circle_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                zipPath.isEmpty ? 'Listo' : p.basename(zipPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Analizar',
              onPressed: busy ? null : onAnalyze,
              icon: const Icon(Icons.refresh),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onExport,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Exportar'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Compartir ZIP',
              onPressed: busy || zipPath.isEmpty ? null : onShare,
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentLine extends StatelessWidget {
  const _AccentLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 4, color: Theme.of(context).colorScheme.primary);
  }
}
