package android.gestor;

import android.AndroidFilePicker;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class GestorRutas {
    public var workspaceRoot:String;
    public var pickedFilesDir:String;
    public var processedDir:String;
    public var stagedExportsDir:String;

    public function new(workspaceRoot:String, pickedFilesDir:String, processedDir:String, stagedExportsDir:String) {
        this.workspaceRoot = workspaceRoot;
        this.pickedFilesDir = pickedFilesDir;
        this.processedDir = processedDir;
        this.stagedExportsDir = stagedExportsDir;
    }
}

class ArchivoSeleccionado {
    public var workspacePath:String;
    public var fileName:String;
    public var extension:String;
    public var sizeBytes:Float;

    public function new(workspacePath:String, fileName:String, extension:String, sizeBytes:Float) {
        this.workspacePath = workspacePath;
        this.fileName = fileName;
        this.extension = extension;
        this.sizeBytes = sizeBytes;
    }
}

class ArchivoGuardado {
    public var sourcePath:String;
    public var targetPath:String;
    public var fileName:String;

    public function new(sourcePath:String, targetPath:String, fileName:String) {
        this.sourcePath = sourcePath;
        this.targetPath = targetPath;
        this.fileName = fileName;
    }
}

class GestorArchivosBackend {
    public static function getRutas():GestorRutas {
        var root = getWorkspaceRoot();
        return new GestorRutas(
            root,
            Path.join([root, "picked-files"]),
            Path.join([root, "processed"]),
            Path.join([root, "exports"])
        );
    }

    public static function getWorkspaceRoot():String {
        #if android
        var fromBridge = AndroidFilePicker.getWorkspaceRoot();
        if (!isBlank(fromBridge)) return fromBridge;
        #end

        #if sys
        return Path.join([Sys.getCwd(), "android-workspace"]);
        #else
        return "android-workspace";
        #end
    }

    public static function getProcessingDir():String {
        var dir = getRutas().processedDir;
        ensureDirectory(dir);
        return dir;
    }

    public static function getStagedExportsDir():String {
        var dir = getRutas().stagedExportsDir;
        ensureDirectory(dir);
        return dir;
    }

    public static function resetWorkspace():Void {
        #if android
        AndroidFilePicker.clearWorkspace();
        #else
        deleteRecursively(getWorkspaceRoot());
        #end
    }

    public static function cleanupAfterSave():Void {
        resetWorkspace();
    }

    public static function openFile(title:String, filter:String, onComplete:ArchivoSeleccionado->Void, onError:String->Void):Bool {
        return AndroidFilePicker.openFile(
            title,
            filter,
            function(path:String) {
                #if android
                android.AppLogger.log("Picker devolvió ruta: " + path);
                #end

                // Bug fix: no validar extensión aquí — el usuario ya eligió
                // el archivo desde el picker del sistema, confiar en eso.
                // Solo verificar que el archivo exista en el workspace.
                var info = describeSelectedFile(path, ""); // sin filtro de extensión
                if (info == null) {
                    var msg = "El archivo no existe en el workspace: " + path;
                    #if android
                    android.AppLogger.err(msg);
                    #end
                    if (onError != null) onError(msg);
                    return;
                }

                #if android
                android.AppLogger.log("Archivo listo: " + info.fileName + " (" + Std.int(info.sizeBytes) + " bytes)");
                #end
                if (onComplete != null) onComplete(info);
            },
            onError
        );
    }

    public static function saveFileToUser(
        title:String,
        suggestedName:String,
        sourcePath:String,
        onComplete:ArchivoGuardado->Void,
        onError:String->Void
    ):Bool {
        if (!fileExists(sourcePath)) {
            if (onError != null) onError("No encontré el archivo preparado para guardar.");
            return false;
        }

        return AndroidFilePicker.saveFile(
            title,
            sanitizeArchiveName(suggestedName),
            sourcePath,
            function(savedPath:String) {
                if (onComplete != null) {
                    onComplete(new ArchivoGuardado(sourcePath, savedPath, Path.withoutDirectory(sanitizeArchiveName(suggestedName))));
                }
            },
            onError
        );
    }

    public static function stageExportZip(sourceZip:String, archiveName:String):String {
        if (!fileExists(sourceZip)) {
            throw "No encontré el ZIP exportado: " + sourceZip;
        }

        var safeName = sanitizeArchiveName(archiveName);
        var targetPath = Path.join([getStagedExportsDir(), safeName]);
        clearFile(targetPath);

        #if sys
        File.saveBytes(targetPath, File.getBytes(sourceZip));
        #end

        return targetPath;
    }

    public static function describeSelectedFile(path:String, expectedExtension:String = ""):ArchivoSeleccionado {
        if (!fileExists(path)) return null;

        var fileName  = Path.withoutDirectory(path);
        var extension = Path.extension(fileName).toLowerCase();

        // Solo verificar extensión si se pasa explícitamente Y el archivo
        // no viene del picker (el picker ya filtra por tipo MIME en el sistema).
        // Si expectedExtension está vacío, aceptar cualquier archivo.
        if (!isBlank(expectedExtension)) {
            var expected = normalizeExtension(expectedExtension);
            if (!isBlank(expected) && extension != expected) {
                // Loguear en vez de rechazar silenciosamente
                #if android
                android.AppLogger.warn("Extensión esperada: '" + expected + "', recibida: '" + extension + "' en " + fileName + " — aceptando igual.");
                #end
                // NO retornar null: el picker del sistema ya validó el archivo,
                // confiar en la elección del usuario.
            }
        }

        var sizeBytes:Float = 0;
        #if sys
        try {
            sizeBytes = FileSystem.stat(path).size;
        } catch (_:Dynamic) {}
        #end

        return new ArchivoSeleccionado(path, fileName, extension, sizeBytes);
    }

    static function sanitizeArchiveName(value:String):String {
        var clean = isBlank(value) ? "spritemap-to-funky.zip" : value;
        if (!StringTools.endsWith(clean.toLowerCase(), ".zip")) clean += ".zip";
        clean = StringTools.replace(clean, "/", "_");
        clean = StringTools.replace(clean, "\\", "_");
        clean = StringTools.replace(clean, ":", "_");
        return clean;
    }

    static function normalizeExtension(value:String):String {
        if (isBlank(value)) return "";
        var clean = StringTools.trim(value).toLowerCase();
        if (StringTools.startsWith(clean, "*.")) clean = clean.substr(2);
        if (StringTools.startsWith(clean, ".")) clean = clean.substr(1);
        return clean;
    }

    static function clearFile(path:String):Void {
        #if sys
        if (fileExists(path)) FileSystem.deleteFile(path);
        #end
    }

    public static function ensureDirectory(path:String):Void {
        #if sys
        if (isBlank(path) || FileSystem.exists(path) && FileSystem.isDirectory(path)) return;

        var parent = Path.directory(path);
        if (!isBlank(parent) && parent != path) ensureDirectory(parent);
        if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
        #end
    }

    static function deleteRecursively(path:String):Void {
        #if sys
        if (isBlank(path) || !FileSystem.exists(path)) return;

        if (FileSystem.isDirectory(path)) {
            for (entry in FileSystem.readDirectory(path)) {
                deleteRecursively(Path.join([path, entry]));
            }
            FileSystem.deleteDirectory(path);
            return;
        }

        FileSystem.deleteFile(path);
        #end
    }

    public static function fileExists(path:String):Bool {
        #if sys
        return !isBlank(path) && FileSystem.exists(path) && !FileSystem.isDirectory(path);
        #else
        return !isBlank(path);
        #end
    }

    public static function directoryExists(path:String):Bool {
        #if sys
        return !isBlank(path) && FileSystem.exists(path) && FileSystem.isDirectory(path);
        #else
        return !isBlank(path);
        #end
    }

    public static function compareStrings(a:String, b:String):Int {
        if (a == b) return 0;
        return a < b ? -1 : 1;
    }

    public static function isBlank(value:String):Bool {
        return value == null || StringTools.trim(value) == "";
    }
}
