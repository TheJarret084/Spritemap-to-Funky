package stf.backend;

import haxe.zip.Writer;
import haxe.zip.Entry;
import haxe.crypto.Crc32;
import sys.FileSystem;
import sys.io.File;

class ZipHelper {
    public static function compressFolder(folder:String, destZip:String):Void {
        var entries = new List<Entry>();
        agregarCarpeta(folder, folder, entries);

        var output = File.write(destZip, true);
        new Writer(output).write(entries);
        output.close();
    }

    static function agregarCarpeta(base:String, current:String, entries:List<Entry>):Void {
        var items = FileSystem.readDirectory(current);
        items.sort(Reflect.compare);

        for (item in items) {
            var fullPath = current + "/" + item;
            var zipName = sanitizeZipPath(fullPath.substr(base.length + 1)); // ruta relativa

            if (FileSystem.isDirectory(fullPath)) {
                agregarCarpeta(base, fullPath, entries);
            } else {
                var datos = File.getBytes(fullPath);
                var entry:Entry = {
                    fileName: zipName,
                    fileSize: datos.length,
                    fileTime: Date.now(),
                    compressed: false,
                    dataSize: datos.length,
                    data: datos,
                    crc32: Crc32.make(datos)
                };
                haxe.zip.Tools.compress(entry, 6);
                entries.add(entry);
            }
        }
    }

    static function sanitizeZipPath(path:String):String {
        var parts:Array<String> = [];
        for (part in path.split("/")) {
            if (part != "") parts.push(Tools.sanitizeName(part));
        }
        return parts.join("/");
    }
}
