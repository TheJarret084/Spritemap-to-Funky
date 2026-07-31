package android.gestor;

import android.AppConfig;
import android.AppLogger;
import android.AppModel.ProjectPaths;
import haxe.io.Path;
import stf.PlatformFolders;

#if sys
import sys.FileSystem;
#end

/**
 * ImportadorMediaBackend
 *
 * - Crea las carpetas de media en el PRIMER INICIO de la app.
 * - Escanea spritemaps/ buscando carpetas que contengan timeline JSON,
 *   atlas JSON y atlas PNG.
 * - Expone la lista de carpetas válidas para el navbar.
 */
class ImportadorMediaBackend {
    static var ANIMATION_JSON_NAMES = [
        AppConfig.REQUIRED_FILE_1,
        "Animation.json",
        "animation.json"
    ];
    static var ATLAS_JSON_NAMES = [
        AppConfig.REQUIRED_FILE_2,
        "spritemap1.json",
        "Spritemap.json",
        "Spritemap1.json"
    ];
    static var ATLAS_PNG_NAMES = [
        AppConfig.REQUIRED_FILE_3,
        "spritemap1.png",
        "Spritemap.png",
        "Spritemap1.png"
    ];

    // ─────────────────────────────────────────────────────────────────────────
    //  Directorios base
    // ─────────────────────────────────────────────────────────────────────────

    static function getMediaBaseDir():String {
        #if android
        return resolvePrimaryMediaBaseDir();
        #elseif sys
        return PlatformFolders.desktopMediaRoot();
        #else
        return Path.join([PlatformFolders.DESKTOP_ROOT_NAME, "media"]);
        #end
    }

    public static function getMediaSpritemapsDir():String {
        #if android
        return resolvePrimarySpritemapsDir();
        #else
        return Path.join([getMediaBaseDir(), "spritemaps"]);
        #end
    }

    public static function getMediaProcessedDir():String {
        #if android
        return AppConfig.getProcessedMediaDir();
        #else
        return PlatformFolders.desktopProcessedDir();
        #end
    }

    public static function getMediaExportsDir():String {
        #if android
        return AppConfig.getExportsDir();
        #else
        return PlatformFolders.desktopExportsDir();
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
            AppConfig.getSpritemapsDir(),
            AppConfig.getProcessedMediaDir(),
            AppConfig.getExportsDir()
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
     * tres archivos requeridos: timeline JSON, atlas JSON y atlas PNG.
     *
     * Ordenada alfabéticamente. Lista vacía si no hay nada.
     */
    public static function findProjectDirectories():Array<String> {
        var results:Array<String> = [];
        #if sys
        var roots = getMediaSpritemapsSearchDirs();
        var existingRoots = [];
        for (root in roots) {
            if (!GestorArchivosBackend.directoryExists(root)) continue;
            existingRoots.push(root);
            collectProjectDirectories(root, results, 0, 4);
        }

        if (existingRoots.length == 0) {
            AppLogger.warn("No existe ninguna carpeta de spritemaps en: " + roots.join(" | "));
            return results;
        }

        results = uniquePaths(results);
        results.sort(GestorArchivosBackend.compareStrings);
        AppLogger.log("Proyectos encontrados: " + results.length + " en " + existingRoots.join(" | "));
        #end
        return results;
    }

    public static function findProjectDirectoriesIn(root:String):Array<String> {
        var results:Array<String> = [];
        #if sys
        if (!GestorArchivosBackend.directoryExists(root)) return results;
        collectProjectDirectories(root, results, 0, 4);
        results = uniquePaths(results);
        results.sort(GestorArchivosBackend.compareStrings);
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
        return loadProjectFromDirectory(candidates[index]);
    }

    public static function loadProjectFromDirectory(projectDir:String):ProjectPaths {
        if (GestorArchivosBackend.isBlank(projectDir)) {
            throw "La ruta del proyecto está vacía.";
        }
        if (!containsProjectFiles(projectDir)) {
            throw "La carpeta no contiene los archivos requeridos: " + projectDir;
        }
        return createProjectPaths(projectDir);
    }

    public static function loadFirstProjectUnder(root:String):ProjectPaths {
        if (containsProjectFiles(root)) return loadProjectFromDirectory(root);

        var candidates = findProjectDirectoriesIn(root);
        if (candidates.length == 0) {
            throw "No encontré proyectos dentro de: " + root +
                  " (necesita " + expectedProjectFilesLabel() + ")";
        }
        return createProjectPaths(candidates[0]);
    }

    /**
     * Carga el PRIMER proyecto válido (comportamiento anterior).
     */
    public static function loadProject():ProjectPaths {
        ensureMediaDirectories();
        var candidates = findProjectDirectories();
        if (candidates.length == 0) {
            throw "No encontré proyectos en " + getMediaSpritemapsSearchDirs().join(" | ") +
                  " (necesita " + expectedProjectFilesLabel() + ")";
        }
        return createProjectPaths(candidates[0]);
    }

    public static function describeImport():String {
        ensureMediaDirectories();
        var candidates = findProjectDirectories();
        var lines = [
            "Buscando proyectos en: " + getMediaSpritemapsSearchDirs().join(" | "),
            "Salida automática en:  " + getMediaProcessedDir()
        ];
        if (candidates.length == 0) {
            lines.push("Todavía no hay carpetas con " + expectedProjectFilesLabel() + ".");
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

    public static function expectedProjectFilesLabel():String {
        return "animations.json/Animation.json + spritemap.json/spritemap1.json + spritemap.png/spritemap1.png";
    }

    public static function hasAnyProjectFile(path:String):Bool {
        return findFirstExistingFile(path, ANIMATION_JSON_NAMES) != ""
            || findFirstExistingFile(path, ATLAS_JSON_NAMES) != ""
            || resolveAtlasPngPath(path, findFirstExistingFile(path, ATLAS_JSON_NAMES)) != "";
    }

    public static function containsProjectFiles(path:String):Bool {
        return resolveProjectFiles(path) != null;
    }

    public static function missingProjectFileLabels(path:String):Array<String> {
        var missing:Array<String> = [];
        var animationJson = findFirstExistingFile(path, ANIMATION_JSON_NAMES);
        var atlasJson = findFirstExistingFile(path, ATLAS_JSON_NAMES);
        var atlasPng = resolveAtlasPngPath(path, atlasJson);

        if (animationJson == "") missing.push("animations.json / Animation.json");
        if (atlasJson == "") missing.push("spritemap.json / spritemap1.json");
        if (atlasPng == "") missing.push("spritemap.png / spritemap1.png");

        return missing;
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

        try {
            var children = FileSystem.readDirectory(path);
            children.sort(GestorArchivosBackend.compareStrings);
            for (entry in children) {
                var child = Path.join([path, entry]);
                if (GestorArchivosBackend.directoryExists(child)) {
                    collectProjectDirectories(child, out, depth + 1, maxDepth);
                }
            }
        } catch (error:Dynamic) {
            AppLogger.warn("No pude leer carpeta media: " + path + " (" + Std.string(error) + ")");
        }
        #end
    }

    static function createProjectPaths(projectDir:String):ProjectPaths {
        var paths = resolveProjectFiles(projectDir);
        if (paths == null) {
            throw "La carpeta no contiene los archivos requeridos: " + projectDir +
                  " (falta " + missingProjectFileLabels(projectDir).join(", ") + ")";
        }

        // Opcionales
        var animsXml = Path.join([projectDir, "anims.xml"]);
        if (GestorArchivosBackend.fileExists(animsXml)) paths.animsXml = animsXml;

        var animsJson = Path.join([projectDir, "anims.json"]);
        if (GestorArchivosBackend.fileExists(animsJson)) paths.animsJson = animsJson;

        AppLogger.log("Proyecto cargado desde: " + projectDir);
        return paths;
    }

    static function resolveProjectFiles(projectDir:String):ProjectPaths {
        var animationJson = findFirstExistingFile(projectDir, ANIMATION_JSON_NAMES);
        var atlasJson = findFirstExistingFile(projectDir, ATLAS_JSON_NAMES);
        var atlasPng = resolveAtlasPngPath(projectDir, atlasJson);

        if (animationJson == "" || atlasJson == "" || atlasPng == "") return null;

        var paths = new ProjectPaths();
        paths.animationJson = animationJson;
        paths.atlasJson = atlasJson;
        paths.atlasPng = atlasPng;
        return paths;
    }

    static function resolveAtlasPngPath(projectDir:String, atlasJson:String):String {
        if (atlasJson != "") {
            var sameBase = Path.withoutExtension(atlasJson) + ".png";
            if (GestorArchivosBackend.fileExists(sameBase)) return sameBase;
        }
        return findFirstExistingFile(projectDir, ATLAS_PNG_NAMES);
    }

    static function findFirstExistingFile(projectDir:String, names:Array<String>):String {
        if (GestorArchivosBackend.isBlank(projectDir) || names == null) return "";

        for (name in names) {
            var path = Path.join([projectDir, name]);
            if (GestorArchivosBackend.fileExists(path)) return path;
        }

        #if sys
        try {
            if (!GestorArchivosBackend.directoryExists(projectDir)) return "";
            var lowerNames = [for (name in names) name.toLowerCase()];
            for (entry in FileSystem.readDirectory(projectDir)) {
                if (lowerNames.indexOf(entry.toLowerCase()) == -1) continue;
                var path = Path.join([projectDir, entry]);
                if (GestorArchivosBackend.fileExists(path)) return path;
            }
        } catch (_:Dynamic) {}
        #end

        return "";
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

    static function resolvePrimaryMediaBaseDir():String {
        var candidates = AppConfig.getMediaDirCandidates();
        for (path in candidates) {
            if (GestorArchivosBackend.directoryExists(path)) return path;
        }
        return AppConfig.getMediaDir();
    }

    static function resolvePrimarySpritemapsDir():String {
        var candidates = getMediaSpritemapsSearchDirs();
        for (path in candidates) {
            if (GestorArchivosBackend.directoryExists(path)) return path;
        }
        return AppConfig.getSpritemapsDir();
    }

    static function getMediaSpritemapsSearchDirs():Array<String> {
        #if android
        return AppConfig.getSpritemapsDirCandidates();
        #else
        return [PlatformFolders.desktopSpritemapsDir()];
        #end
    }

    static function uniquePaths(paths:Array<String>):Array<String> {
        var out:Array<String> = [];
        var seen:Array<String> = [];
        for (path in paths) {
            if (GestorArchivosBackend.isBlank(path)) continue;
            var key = GestorArchivosBackend.normalizePathKey(path);
            if (key == "" || seen.indexOf(key) != -1) continue;
            seen.push(key);
            out.push(path);
        }
        return out;
    }
}
