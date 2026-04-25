package android.gestor;

import android.AppConfig;
import android.AppLogger;
import android.AppModel.ProjectPaths;
import haxe.io.Path;

#if sys
import sys.FileSystem;
#end

/**
 * ImportadorMediaBackend
 *
 * - Crea las carpetas de media en el PRIMER INICIO de la app.
 * - Escanea spritemaps/ buscando carpetas que contengan los tres archivos
 *   requeridos: animations.json, spritemap.json, spritemap.png
 * - Expone la lista de carpetas válidas para el navbar.
 */
class ImportadorMediaBackend {

    // ─────────────────────────────────────────────────────────────────────────
    //  Directorios base
    // ─────────────────────────────────────────────────────────────────────────

    static function getMediaBaseDir():String {
        #if android
        return AppConfig.getMediaDir();
        #elseif sys
        return Path.join([Sys.getCwd(), AppConfig.PACKAGE_NAME]);
        #else
        return AppConfig.PACKAGE_NAME;
        #end
    }

    public static function getMediaSpritemapsDir():String {
        #if android
        return AppConfig.getSpritemapsDir();
        #else
        return Path.join([getMediaBaseDir(), "spritemaps"]);
        #end
    }

    public static function getMediaProcessedDir():String {
        #if android
        return AppConfig.getProcessedMediaDir();
        #else
        return Path.join([getMediaBaseDir(), "processed"]);
        #end
    }

    public static function getMediaExportsDir():String {
        #if android
        return AppConfig.getExportsDir();
        #else
        return Path.join([getMediaBaseDir(), "exports"]);
        #end
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Primer inicio: crear todas las carpetas necesarias
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Llama esto al arrancar la app (en AndroidApp.onPreloadComplete).
     * Crea silenciosamente las carpetas si no existen.
     * Loguea lo que hace para que aparezca en la consola de la app.
     */
    public static function ensureMediaDirectories():Void {
        var dirs = [
            getMediaSpritemapsDir(),
            getMediaProcessedDir(),
            getMediaExportsDir()
        ];

        for (dir in dirs) {
            var existed = GestorArchivosBackend.directoryExists(dir);
            GestorArchivosBackend.ensureDirectory(dir);
            if (!existed) {
                AppLogger.log("Carpeta creada: " + dir);
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Escaneo de proyectos válidos (para el navbar)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Devuelve la lista de carpetas dentro de spritemaps/ que contienen los
     * tres archivos requeridos:
     *   - animations.json
     *   - spritemap.json
     *   - spritemap.png
     *
     * Ordenada alfabéticamente. Lista vacía si no hay nada.
     */
    public static function findProjectDirectories():Array<String> {
        var results:Array<String> = [];
        #if sys
        var root = getMediaSpritemapsDir();
        if (!GestorArchivosBackend.directoryExists(root)) {
            AppLogger.warn("No existe la carpeta de spritemaps: " + root);
            return results;
        }
        collectProjectDirectories(root, results, 0, 4);
        results.sort(GestorArchivosBackend.compareStrings);
        AppLogger.log("Proyectos encontrados: " + results.length + " en " + root);
        #end
        return results;
    }

    /**
     * Igual que findProjectDirectories() pero devuelve solo los nombres
     * cortos de carpeta (para mostrar en el navbar).
     */
    public static function findProjectNames():Array<String> {
        var dirs = findProjectDirectories();
        return [for (d in dirs) Path.withoutDirectory(d)];
    }

    /**
     * Carga el proyecto que está en el índice `index` de la lista de
     * carpetas válidas.
     */
    public static function loadProjectAt(index:Int):ProjectPaths {
        var candidates = findProjectDirectories();
        if (index < 0 || index >= candidates.length) {
            throw "Índice de proyecto fuera de rango: " + index;
        }
        return createProjectPaths(candidates[index]);
    }

    /**
     * Carga el PRIMER proyecto válido (comportamiento anterior).
     */
    public static function loadProject():ProjectPaths {
        ensureMediaDirectories();
        var candidates = findProjectDirectories();
        if (candidates.length == 0) {
            throw "No encontré proyectos en " + getMediaSpritemapsDir() +
                  " (necesita animations.json + spritemap.json + spritemap.png)";
        }
        return createProjectPaths(candidates[0]);
    }

    public static function describeImport():String {
        ensureMediaDirectories();
        var candidates = findProjectDirectories();
        var lines = [
            "Buscando proyectos en: " + getMediaSpritemapsDir(),
            "Salida automática en:  " + getMediaProcessedDir()
        ];
        if (candidates.length == 0) {
            lines.push("Todavía no hay carpetas con animations.json + spritemap.json + spritemap.png.");
        } else {
            lines.push("Proyecto usado: " + candidates[0]);
            if (candidates.length > 1)
                lines.push("Encontré " + candidates.length + " proyectos; usé el primero.");
        }
        return lines.join("\n");
    }

    public static function buildProcessedOutputDir(paths:ProjectPaths):String {
        ensureMediaDirectories();
        var baseName = deriveProjectBaseName(paths);
        return Path.join([getMediaProcessedDir(), sanitizeFolderName(baseName)]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Internos
    // ─────────────────────────────────────────────────────────────────────────

    static function collectProjectDirectories(path:String, out:Array<String>, depth:Int, maxDepth:Int):Void {
        #if sys
        if (!GestorArchivosBackend.directoryExists(path)) return;

        if (containsProjectFiles(path)) {
            out.push(path);
            return; // no seguir buscando dentro si ya es un proyecto
        }

        if (depth >= maxDepth) return;

        var children = FileSystem.readDirectory(path);
        children.sort(GestorArchivosBackend.compareStrings);
        for (entry in children) {
            var child = Path.join([path, entry]);
            if (GestorArchivosBackend.directoryExists(child)) {
                collectProjectDirectories(child, out, depth + 1, maxDepth);
            }
        }
        #end
    }

    /**
     * Una carpeta es "proyecto válido" si tiene los tres archivos clave.
     * Los nombres vienen de AppConfig para que sean fáciles de cambiar.
     */
    static function containsProjectFiles(path:String):Bool {
        return GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_1]))   // animations.json
            && GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_2]))   // spritemap.json
            && GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_3]));  // spritemap.png
    }

    static function createProjectPaths(projectDir:String):ProjectPaths {
        var paths = new ProjectPaths();

        paths.animationJson = Path.join([projectDir, AppConfig.REQUIRED_FILE_1]); // animations.json
        paths.atlasJson     = Path.join([projectDir, AppConfig.REQUIRED_FILE_2]); // spritemap.json
        paths.atlasPng      = Path.join([projectDir, AppConfig.REQUIRED_FILE_3]); // spritemap.png

        // Opcionales
        var animsXml = Path.join([projectDir, "anims.xml"]);
        if (GestorArchivosBackend.fileExists(animsXml)) paths.animsXml = animsXml;

        var animsJson = Path.join([projectDir, "anims.json"]);
        if (GestorArchivosBackend.fileExists(animsJson)) paths.animsJson = animsJson;

        AppLogger.log("Proyecto cargado desde: " + projectDir);
        return paths;
    }

    static function deriveProjectBaseName(paths:ProjectPaths):String {
        var base = "";
        if (paths != null) {
            if (!GestorArchivosBackend.isBlank(paths.animsJson))
                base = Path.withoutExtension(Path.withoutDirectory(paths.animsJson));
            else if (!GestorArchivosBackend.isBlank(paths.animsXml))
                base = Path.withoutExtension(Path.withoutDirectory(paths.animsXml));
            else if (!GestorArchivosBackend.isBlank(paths.animationJson)) {
                var dir = Path.directory(paths.animationJson);
                base = Path.withoutDirectory(dir);
                if (GestorArchivosBackend.isBlank(base))
                    base = Path.withoutExtension(Path.withoutDirectory(paths.animationJson));
            }
        }
        if (GestorArchivosBackend.isBlank(base)) base = "spritemap-to-funky";
        return base;
    }

    static function sanitizeFolderName(value:String):String {
        var clean = GestorArchivosBackend.isBlank(value) ? "spritemap-to-funky" : value;
        for (bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"])
            clean = StringTools.replace(clean, bad, "_");
        return clean;
    }
}
