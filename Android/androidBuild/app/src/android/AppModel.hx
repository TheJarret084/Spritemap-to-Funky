package android;

class ProjectPaths {
    public var animationJson:String = "";
    public var atlasJson:String = "";
    public var atlasPng:String = "";
    public var animsXml:String = "";
    public var animsJson:String = "";
    public var outputDir:String = "";

    public function new() {}

    public function clone():ProjectPaths {
        var copy = new ProjectPaths();
        copy.animationJson = animationJson;
        copy.atlasJson = atlasJson;
        copy.atlasPng = atlasPng;
        copy.animsXml = animsXml;
        copy.animsJson = animsJson;
        copy.outputDir = outputDir;
        return copy;
    }
}

class AnimationChoice {
    public var name:String;
    public var source:String;
    public var indices:Array<Int>;
    public var selected:Bool;

    public function new(name:String, source:String, ?indices:Array<Int>, selected:Bool = true) {
        this.name = name;
        this.source = source;
        this.indices = indices != null ? indices.copy() : [];
        this.selected = selected;
    }

    public function clone():AnimationChoice {
        return new AnimationChoice(name, source, indices, selected);
    }

    public function label():String {
        return name == source ? name : name + " -> " + source;
    }
}

class LoadResult {
    public var animations:Array<AnimationChoice>;
    public var log:String;

    public function new(?animations:Array<AnimationChoice>, log:String = "") {
        this.animations = animations != null ? animations : [];
        this.log = log;
    }
}

class ExportResult {
    public var log:String;
    public var outputDir:String;
    public var filesWritten:Int;
    public var zipPath:String;
    public var archivePath:String;
    public var archiveName:String;

    public function new(
        log:String = "",
        outputDir:String = "",
        filesWritten:Int = 0,
        zipPath:String = "",
        archivePath:String = "",
        archiveName:String = ""
    ) {
        this.log = log;
        this.outputDir = outputDir;
        this.filesWritten = filesWritten;
        this.zipPath = zipPath;
        this.archivePath = archivePath;
        this.archiveName = archiveName;
    }
}
