import 'dart:typed_data';

class Transform {
  Transform({
    this.a = 1,
    this.b = 0,
    this.c = 0,
    this.d = 1,
    this.tx = 0,
    this.ty = 0,
  });

  double a;
  double b;
  double c;
  double d;
  double tx;
  double ty;
}

class AtlasSpriteDef {
  AtlasSpriteDef({
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
    this.rotated = false,
  });

  int x;
  int y;
  int w;
  int h;
  bool rotated;
}

enum ElementType { atlasSprite, symbolInstance }

class TimelineElement {
  TimelineElement(this.type);

  ElementType type;
  String name = '';
  Transform transform = Transform();
  int firstFrame = 0;
  String symbolType = '';
  String loop = '';
}

class TimelineFrame {
  int start = 0;
  int duration = 0;
  final elements = <TimelineElement>[];
}

class TimelineLayer {
  final frames = <TimelineFrame>[];
}

class TimelineData {
  final layers = <TimelineLayer>[];
  int totalFrames = 0;
}

class SymbolDef {
  SymbolDef({this.name = ''});

  String name;
  TimelineData timeline = TimelineData();
}

class AnimDef {
  AnimDef(this.name, this.sourceAnim, [List<int>? indices])
      : indices = List<int>.of(indices ?? const []);

  String name;
  String sourceAnim;
  List<int> indices;
  bool selected = true;
}

class Bounds {
  double minx = 0;
  double miny = 0;
  double maxx = 0;
  double maxy = 0;
  bool initialized = false;

  void include(double minx, double miny, double maxx, double maxy) {
    if (!initialized) {
      this.minx = minx;
      this.miny = miny;
      this.maxx = maxx;
      this.maxy = maxy;
      initialized = true;
      return;
    }

    if (minx < this.minx) this.minx = minx;
    if (miny < this.miny) this.miny = miny;
    if (maxx > this.maxx) this.maxx = maxx;
    if (maxy > this.maxy) this.maxy = maxy;
  }
}

class RgbaImage {
  RgbaImage(this.width, this.height, [Uint8List? pixels])
      : pixels = pixels ?? Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;

  int pixelOffset(int x, int y) => ((y * width) + x) << 2;
}

class ExportJob {
  ExportJob(this.symbol, this.outName, List<int>? frames)
      : frames = List<int>.of(frames ?? const []);

  SymbolDef symbol;
  String outName;
  List<int> frames;
}

class ProjectPaths {
  const ProjectPaths({
    this.animationJson = '',
    this.atlasJson = '',
    this.atlasPng = '',
    this.animsXml = '',
    this.animsJson = '',
    this.outputDir = '',
  });

  final String animationJson;
  final String atlasJson;
  final String atlasPng;
  final String animsXml;
  final String animsJson;
  final String outputDir;

  ProjectPaths copyWith({
    String? animationJson,
    String? atlasJson,
    String? atlasPng,
    String? animsXml,
    String? animsJson,
    String? outputDir,
  }) {
    return ProjectPaths(
      animationJson: animationJson ?? this.animationJson,
      atlasJson: atlasJson ?? this.atlasJson,
      atlasPng: atlasPng ?? this.atlasPng,
      animsXml: animsXml ?? this.animsXml,
      animsJson: animsJson ?? this.animsJson,
      outputDir: outputDir ?? this.outputDir,
    );
  }
}

class DescribeResult {
  const DescribeResult({
    required this.animations,
    required this.previewPath,
    required this.outputDir,
    required this.log,
  });

  final List<AnimDef> animations;
  final String previewPath;
  final String outputDir;
  final String log;
}

class ExportResult {
  const ExportResult({
    required this.ok,
    required this.log,
    this.outputDir = '',
    this.zipPath = '',
    this.filesWritten = 0,
    this.totalFrames = 0,
  });

  final bool ok;
  final String log;
  final String outputDir;
  final String zipPath;
  final int filesWritten;
  final int totalFrames;
}
