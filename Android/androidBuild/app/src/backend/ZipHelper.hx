package backend;

import haxe.zip.Writer;
import haxe.zip.Entry;
import haxe.zip.Tools;
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
        for (item in FileSystem.readDirectory(current)) {
            var fullPath = current + "/" + item;
            var zipName = fullPath.substr(base.length + 1); // ruta relativa

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
                    crc32: null
                };
                Tools.compress(entry, 6);
                entries.add(entry);
            }
        }
    }
}