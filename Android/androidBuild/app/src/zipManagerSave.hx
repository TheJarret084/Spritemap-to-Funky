import haxe.zip.Writer;
import haxe.zip.Entry;
import haxe.zip.Tools;
import sys.io.File;

function exportarZip(png:haxe.io.Bytes, json1:String, json2:String, destino:String) {
    var entries = new List<Entry>();

    // Agregar cada archivo
    function agregarArchivo(nombre:String, datos:haxe.io.Bytes) {
        var entry:Entry = {
            fileName: nombre,
            fileSize: datos.length,
            fileTime: Date.now(),
            compressed: false,
            dataSize: datos.length,
            data: datos,
            crc32: null
        };
        Tools.compress(entry, 6); // nivel de compresión 1-9
        entries.add(entry);
    }

    agregarArchivo("spritesheet.png", png);
    agregarArchivo("data1.json", haxe.io.Bytes.ofString(json1));
    agregarArchivo("data2.json", haxe.io.Bytes.ofString(json2));

    // Guardar el ZIP
    var output = File.write(destino, true);
    new Writer(output).write(entries);
    output.close();
}

// modificar despues