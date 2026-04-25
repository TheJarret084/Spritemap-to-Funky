package android;

import haxe.Json;
import lime.utils.Assets as LimeAssets;
import openfl.Assets;

// ─── Datos del panel About ───────────────────────────────────────────────────

class ProjectInfoData {
    public var panelTitle:String;
    public var linkLabel:String;
    public var projectName:String;
    public var projectUrl:String;
    public var overviewLines:Array<String>;
    public var teamEntries:Array<ProjectInfoEntryData>;
    public var extraLines:Array<String>;

    public function new() {
        panelTitle = "";
        linkLabel  = "";
        projectName = "";
        projectUrl  = "";
        overviewLines = [];
        teamEntries   = [];
        extraLines    = [];
    }
}

class ProjectInfoEntryData {
    public var text:String;
    public var icon:String;

    public function new(?text:String = "", ?icon:String = "") {
        this.text = text;
        this.icon = icon;
    }
}

// ─── Config central de la app ────────────────────────────────────────────────

class AppConfig {

    // ── Textos generales ──────────────────────────────────────────────────────
    public static inline var APP_TITLE:String      = "Spritemap to Funky!";
    public static inline var APP_SUBTITLE:String   = "Convierte el spritemap de Adobe Animate en frames y ZIPs listos desde Android.";
    public static inline var PACKAGE_NAME:String   = "com.thejarretlabs.spritemaptofunky";

    // ── Assets ────────────────────────────────────────────────────────────────
    public static inline var SPLASH_ASSET_PATH:String     = "other/cualeselproblema.jpg";
    public static inline var BROWSE_ICON_ASSET:String     = "buttons/addFilesExport.png";
    public static inline var ABOUT_ICON_ASSET:String      = "icons/icon.png";
    public static inline var PROJECT_INFO_ASSET_PATH:String = "other/project-info.json";

    // ── Splash ────────────────────────────────────────────────────────────────
    public static inline var SPLASH_DURATION_MS:Int = 2200;
    public static inline var SPLASH_FADE_MS:Int     = 360;

    // ── Colores ───────────────────────────────────────────────────────────────
    public static inline var BACKGROUND_COLOR:Int = 0x050816;

    // ── Diálogos ──────────────────────────────────────────────────────────────
    public static inline var SAVE_DIALOG_TITLE:String = "Guardar ZIP";

    // ── Caros Edition ─────────────────────────────────────────────────────────
    //   Solo se compila si haces: lime build android -D caros
    //   NO está relacionado con -debug ni con ningún otro flag automático.
    #if caros
    public static inline var CAROS_VIDEO_ASSET:String     = "other/jejeje.mp4";
    public static inline var CAROS_VIDEO_DURATION_MS:Int  = 16000;
    public static inline var CAROS_DIALOG_TITLE:String    = "Error Fatal";
    public static inline var CAROS_DIALOG_MESSAGE:String  = "Se detecto un problema critico. La app se cerrara.";
    #end

    // ── Archivos de proyecto válidos (para el navbar de carpetas) ─────────────
    //   Una carpeta se considera "proyecto" si tiene los tres.
    public static inline var REQUIRED_FILE_1:String = "animations.json";
    public static inline var REQUIRED_FILE_2:String = "spritemap.json";
    public static inline var REQUIRED_FILE_3:String = "spritemap.png";

    // ─────────────────────────────────────────────────────────────────────────
    //  Cache interno
    // ─────────────────────────────────────────────────────────────────────────
    static var projectInfoCache:ProjectInfoData;

    // ─────────────────────────────────────────────────────────────────────────
    //  Rutas de Android  (llamar solo DESPUÉS de que Lime haya iniciado)
    // ─────────────────────────────────────────────────────────────────────────
    #if android
    /** /data/data/com.app/files/  ── privado, borrable por el sistema */
    public static function getInternalDir():String {
        return lime.system.System.applicationStorageDirectory;
    }

    /** /sdcard/Android/media/com.app/  ── visible al usuario, sin permisos extra */
    public static function getMediaDir():String {
        return "/sdcard/Android/media/" + PACKAGE_NAME + "/";
    }

    /** Carpeta donde el usuario pone sus proyectos (con las tres keys) */
    public static function getSpritemapsDir():String {
        return getMediaDir() + "spritemaps/";
    }

    /** Resultados procesados en media */
    public static function getProcessedMediaDir():String {
        return getMediaDir() + "processed/";
    }

    /** ZIPs exportados en media */
    public static function getExportsDir():String {
        return getMediaDir() + "exports/";
    }

    /** Carpeta temporal de procesamiento, en storage interno */
    public static function getProcessedDir():String {
        return getInternalDir() + "processed/";
    }

    #if caros
    /** Ruta donde se extrae el video de caros del APK */
    public static function getCarosVideoPath():String {
        return getInternalDir() + "jejeje.mp4";
    }
    #end
    #end

    // ─────────────────────────────────────────────────────────────────────────
    //  Resolución de assets
    // ─────────────────────────────────────────────────────────────────────────
    public static function resolveAssetPath(path:String):String {
        if (path == null || StringTools.trim(path) == "") return path;

        var normalized = StringTools.startsWith(path, "assets/") ? path.substr("assets/".length) : path;
        var prefixed   = StringTools.startsWith(path, "assets/") ? path : "assets/" + path;

        if (Assets.exists(normalized)  || LimeAssets.exists(normalized))  return normalized;
        if (Assets.exists(prefixed)    || LimeAssets.exists(prefixed))     return prefixed;

        return normalized;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  project-info.json
    // ─────────────────────────────────────────────────────────────────────────
    public static function getProjectInfo():ProjectInfoData {
        if (projectInfoCache != null) return projectInfoCache;

        var info = defaultProjectInfo();
        var assetPath = resolveAssetPath(PROJECT_INFO_ASSET_PATH);
        var raw:String = null;

        try {
            if      (Assets.exists(assetPath))     raw = Assets.getText(assetPath);
            else if (LimeAssets.exists(assetPath)) raw = LimeAssets.getText(assetPath);
        } catch (_:Dynamic) {}

        if (raw != null && StringTools.trim(raw) != "") {
            try {
                var data:Dynamic = Json.parse(raw);
                info.panelTitle   = readString(data, "panelTitle",   info.panelTitle);
                info.linkLabel    = readString(data, "linkLabel",     info.linkLabel);
                info.projectName  = readString(data, "projectName",   info.projectName);
                info.projectUrl   = readStringOrFirstArrayValue(data, "projectUrl", info.projectUrl);
                info.overviewLines = readStringArray(data, "overviewLines", info.overviewLines);
                info.teamEntries   = readEntryArray(data, "teamEntries", info.teamEntries);
                if (info.teamEntries.length == 0) {
                    var legacy = readStringArray(data, "teamLines", []);
                    for (line in legacy) info.teamEntries.push(new ProjectInfoEntryData(line, ""));
                }
                info.extraLines = readStringArray(data, "extraLines", info.extraLines);
            } catch (_:Dynamic) {}
        }

        projectInfoCache = info;
        return projectInfoCache;
    }

    static function defaultProjectInfo():ProjectInfoData {
        var info = new ProjectInfoData();
        info.overviewLines = [
            "Herramienta para convertir spritemaps exportados desde Adobe Animate en animaciones listas para empaquetar en ZIP.",
            "La build Android exporta directo a ZIP y ya no arrastra flujo de Aseprite."
        ];
        info.teamEntries = [
            new ProjectInfoEntryData("Colaboradores: JarretLabs",         "icons/icon.png"),
            new ProjectInfoEntryData("Coders: Jarret",                    "buttons/addFilesExport.png"),
            new ProjectInfoEntryData("Artistas: pendiente por editar en JSON", ""),
            new ProjectInfoEntryData("Testers: pendiente por editar en JSON",  "")
        ];
        info.extraLines = [
            "Descarga el proyecto completo desde GitHub para builds de escritorio o cambios al backend.",
            "Edita project-info.json para cambiar creditos, links y texto extra sin tocar la UI."
        ];
        return info;
    }

    // ─── helpers para parsear JSON ────────────────────────────────────────────

    static function readString(data:Dynamic, fieldName:String, fallback:String):String {
        if (data == null || !Reflect.hasField(data, fieldName)) return fallback;
        var v = Reflect.field(data, fieldName);
        return v == null ? fallback : Std.string(v);
    }

    static function readStringOrFirstArrayValue(data:Dynamic, fieldName:String, fallback:String):String {
        if (data == null || !Reflect.hasField(data, fieldName)) return fallback;
        var v:Dynamic = Reflect.field(data, fieldName);
        if (v == null) return fallback;
        if (Std.isOfType(v, Array)) {
            for (entry in cast(v, Array<Dynamic>)) {
                if (entry == null) continue;
                var text = StringTools.trim(Std.string(entry));
                if (text != "") return text;
            }
            return fallback;
        }
        var text = StringTools.trim(Std.string(v));
        return text == "" ? fallback : text;
    }

    static function readStringArray(data:Dynamic, fieldName:String, fallback:Array<String>):Array<String> {
        if (data == null || !Reflect.hasField(data, fieldName)) return fallback.copy();
        var v:Dynamic = Reflect.field(data, fieldName);
        if (!Std.isOfType(v, Array)) return fallback.copy();
        var out:Array<String> = [];
        for (entry in cast(v, Array<Dynamic>)) if (entry != null) out.push(Std.string(entry));
        return out.length > 0 ? out : fallback.copy();
    }

    static function readEntryArray(data:Dynamic, fieldName:String, fallback:Array<ProjectInfoEntryData>):Array<ProjectInfoEntryData> {
        if (data == null || !Reflect.hasField(data, fieldName)) return cloneEntries(fallback);
        var v:Dynamic = Reflect.field(data, fieldName);
        if (!Std.isOfType(v, Array)) return cloneEntries(fallback);
        var out:Array<ProjectInfoEntryData> = [];
        for (entry in cast(v, Array<Dynamic>)) {
            if (entry == null) continue;
            if (Std.isOfType(entry, String)) { out.push(new ProjectInfoEntryData(Std.string(entry), "")); continue; }
            var text = Reflect.hasField(entry, "text") ? Std.string(Reflect.field(entry, "text")) : "";
            var icon = Reflect.hasField(entry, "icon") ? Std.string(Reflect.field(entry, "icon")) : "";
            if (StringTools.trim(text) == "") continue;
            out.push(new ProjectInfoEntryData(text, icon));
        }
        return out.length > 0 ? out : cloneEntries(fallback);
    }

    static function cloneEntries(entries:Array<ProjectInfoEntryData>):Array<ProjectInfoEntryData> {
        var out:Array<ProjectInfoEntryData> = [];
        for (entry in entries) if (entry != null) out.push(new ProjectInfoEntryData(entry.text, entry.icon));
        return out;
    }
}
