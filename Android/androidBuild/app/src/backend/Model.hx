package backend;

import haxe.io.Bytes;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.ImageFileFormat;
import lime.graphics.PixelFormat;
import lime.utils.UInt8Array;
import sys.io.File;

class Transform {
    public var a:Float;
    public var b:Float;
    public var c:Float;
    public var d:Float;
    public var tx:Float;
    public var ty:Float;

    public function new() {
        a = 1.0;
        b = 0.0;
        c = 0.0;
        d = 1.0;
        tx = 0.0;
        ty = 0.0;
    }
}

class AtlasSpriteDef {
    public var x:Int = 0;
    public var y:Int = 0;
    public var w:Int = 0;
    public var h:Int = 0;
    public var rotated:Bool = false;

    public function new() {}
}

enum ElementType {
    AtlasSprite;
    SymbolInstance;
}

class TimelineElement {
    public var type:ElementType;
    public var name:String = "";
    public var transform:Transform;
    public var firstFrame:Int = 0;
    public var symbolType:String = "";
    public var loop:String = "";

    public function new(type:ElementType) {
        this.type = type;
        transform = new Transform();
    }
}

class TimelineFrame {
    public var start:Int = 0;
    public var duration:Int = 0;
    public var elements:Array<TimelineElement> = [];

    public function new() {}
}

class TimelineLayer {
    public var frames:Array<TimelineFrame> = [];

    public function new() {}
}

class TimelineData {
    public var layers:Array<TimelineLayer> = [];
    public var totalFrames:Int = 0;

    public function new() {}
}

class SymbolDef {
    public var name:String = "";
    public var timeline:TimelineData;

    public function new() {
        timeline = new TimelineData();
    }
}

class AnimDef {
    public var name:String;
    public var sourceAnim:String;
    public var indices:Array<Int>;

    public function new(name:String, sourceAnim:String, ?indices:Array<Int>) {
        this.name = name;
        this.sourceAnim = sourceAnim;
        this.indices = indices != null ? indices.copy() : [];
    }
}

class Bounds {
    public var minx:Float = 0.0;
    public var miny:Float = 0.0;
    public var maxx:Float = 0.0;
    public var maxy:Float = 0.0;
    public var initialized:Bool = false;

    public function new() {}

    public function include(minx:Float, miny:Float, maxx:Float, maxy:Float):Void {
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
    public var width:Int;
    public var height:Int;
    public var pixels:Bytes;

    public function new(width:Int, height:Int, ?pixels:Bytes) {
        this.width = width;
        this.height = height;
        this.pixels = pixels != null ? pixels : Bytes.alloc(width * height * 4);
    }

    public static function create(width:Int, height:Int):RgbaImage {
        return new RgbaImage(width, height);
    }

    public static function fromFile(path:String):RgbaImage {
        var image = Image.fromFile(path);
        if (image == null || image.buffer == null) {
            throw "No pude cargar PNG: " + path;
        }

        var bytes = image.getPixels(image.rect, PixelFormat.RGBA32);
        if (bytes == null) {
            throw "No pude leer los pixels del PNG: " + path;
        }

        return new RgbaImage(image.width, image.height, bytes);
    }

    public inline function pixelOffset(x:Int, y:Int):Int {
        return ((y * width) + x) << 2;
    }

    public function writePng(path:String):Void {
        var buffer = new ImageBuffer(UInt8Array.fromBytes(pixels), width, height, 32, PixelFormat.RGBA32);
        var image = new Image(buffer);
        File.saveBytes(path, image.encode(ImageFileFormat.PNG));
    }
}

class ExportJob {
    public var symbol:SymbolDef;
    public var outName:String;
    public var frames:Array<Int>;

    public function new(symbol:SymbolDef, outName:String, frames:Array<Int>) {
        this.symbol = symbol;
        this.outName = outName;
        this.frames = frames != null ? frames.copy() : [];
    }
}
