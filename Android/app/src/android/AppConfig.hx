package android;

import haxe.Json;
import lime.utils.Assets as LimeAssets;
import openfl.Assets;
import openfl.display.BitmapData;
import stf.PlatformFolders;

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
    public static inline var APP_SUBTITLE:String   = "Convierte spritemaps de Adobe Animate en animaciones y ZIPs listos.";
    public static inline var PACKAGE_NAME:String   = "com.thejarretlabs.spritemaptofunky";

    // ── Discord RPC (desktop solamente) ─────────────────────────────────────
    //   Pon aquí el Application ID real de tu app de Discord Developer Portal.
    public static inline var DISCORD_APP_ID:String            = "1497540409641926786"; // app id segun discord developer portal
    public static inline var DISCORD_DEFAULT_DETAILS:String   = "Viendo spritemaps";
    public static inline var DISCORD_DEFAULT_STATE:String     = "Haciendo nada";
    public static inline var DISCORD_LARGE_IMAGE_KEY:String   = ""; // ni puta idea de qué poner aquí
    public static inline var DISCORD_LARGE_IMAGE_TEXT:String  = "Spritemap to Funky";
    public static inline var DISCORD_SMALL_IMAGE_KEY:String   = ""; // ni puta idea de qué poner aquí
    public static inline var DISCORD_SMALL_IMAGE_TEXT:String  = ""; // ni puta idea de qué poner aquí

    // ── Assets ────────────────────────────────────────────────────────────────
    public static inline var SPLASH_ASSET_PATH:String     = "other/banner.png";
    public static inline var BROWSE_ICON_ASSET:String     = "buttons/addFilesExport.png";
    public static inline var ABOUT_ICON_ASSET:String      = "info-icons/icon/icon.png";
    public static inline var PROJECT_INFO_ASSET_PATH:String = "other/project-info.json";

    // ── Splash ────────────────────────────────────────────────────────────────
    public static inline var SPLASH_DURATION_MS:Int = 2200;
    public static inline var SPLASH_FADE_MS:Int     = 360;

    // ── Tema oscuro ──────────────────────────────────────────────────────────
    public static inline var BACKGROUND_COLOR:Int    = 0x101418;
    public static inline var COLOR_SURFACE:Int       = 0x171C20;
    public static inline var COLOR_SURFACE_ALT:Int   = 0x20262B;
    public static inline var COLOR_PANEL:Int         = 0x14191D;
    public static inline var COLOR_TEXT:Int          = 0xEEF2E8;
    public static inline var COLOR_MUTED:Int         = 0xAAB4A2;
    public static inline var COLOR_BORDER:Int        = 0x3D4840;
    public static inline var COLOR_ACCENT:Int        = 0x7CB342;
    public static inline var COLOR_ACCENT_SOFT:Int   = 0x23351F;
    public static inline var COLOR_INFO:Int          = 0x64B5F6;
    public static inline var COLOR_WARN:Int          = 0xFBBF24;
    public static inline var COLOR_DANGER:Int        = 0xF87171;
    public static inline var COLOR_DANGER_SOFT:Int   = 0x3A1518;

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
    /** /data/data/com.app/files/  ── privado, borrable por el sistema */
    public static function getInternalDir():String {
        #if android
        return lime.system.System.applicationStorageDirectory;
        #elseif sys
        return normalizeDir(PlatformFolders.desktopWorkspaceRoot());
        #else
        return PlatformFolders.DESKTOP_ROOT_NAME + "/workspace/";
        #end
    }

    /** /sdcard/Android/media/com.app/  ── visible al usuario, sin permisos extra */
    public static function getMediaDir():String {
        #if android
        var fromBridge = normalizeDir(AndroidFilePicker.getExternalMediaRoot());
        if (fromBridge != "") return fromBridge;
        return "/sdcard/Android/media/" + PACKAGE_NAME + "/";
        #elseif sys
        return normalizeDir(PlatformFolders.desktopMediaRoot());
        #else
        return PlatformFolders.DESKTOP_ROOT_NAME + "/media/";
        #end
    }

    /** Rutas candidatas para builds/dispositivos con variaciones de storage. */
    public static function getMediaDirCandidates():Array<String> {
        #if android
        var candidates = [
            getMediaDir(),
            "/sdcard/Android/media/" + PACKAGE_NAME + "/",
            "/storage/emulated/0/Android/media/" + PACKAGE_NAME + "/",
            "/sdcard/Android/media/package_name/",
            "/storage/emulated/0/Android/media/package_name/"
        ];
        #else
        var candidates = [getMediaDir()];
        #end

        var out:Array<String> = [];
        for (path in candidates) {
            if (path == null || StringTools.trim(path) == "") continue;
            if (out.indexOf(path) == -1) out.push(path);
        }
        return out;
    }

    /** Carpeta donde el usuario pone sus proyectos (con las tres keys) */
    public static function getSpritemapsDir():String {
        return getMediaDir() + "spritemaps/";
    }

    public static function getSpritemapsDirCandidates():Array<String> {
        return [for (base in getMediaDirCandidates()) base + "spritemaps/"];
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

    static function normalizeDir(path:String):String {
        if (path == null) return "";
        var clean = StringTools.trim(path);
        if (clean == "") return "";
        return StringTools.endsWith(clean, "/") ? clean : clean + "/";
    }

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

    public static function assetExists(path:String):Bool {
        var assetPath = resolveAssetPath(path);
        return Assets.exists(assetPath) || LimeAssets.exists(assetPath);
    }

    public static function getBitmapData(path:String):BitmapData {
        var assetPath = resolveAssetPath(path);
        try {
            if (Assets.exists(assetPath) || LimeAssets.exists(assetPath)) {
                return Assets.getBitmapData(assetPath);
            }
        } catch (_:Dynamic) {}
        return null;
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
        info.panelTitle = "Informacion del proyecto";
        info.linkLabel  = "Abrir enlace";
        info.projectName = "Proyecto sin configurar";
        info.projectUrl  = "";
        info.overviewLines = [
            "No se encontro un archivo project-info.json valido.",
            "Puedes personalizar este panel editando assets/other/project-info.json."
        ];
        info.teamEntries = [
            new ProjectInfoEntryData("Agrega colaboradores desde el JSON", ""),
            new ProjectInfoEntryData("Puedes usar color, negrita y tachado en los textos", "")
        ];
        info.extraLines = [
            "Campos soportados: panelTitle, linkLabel, projectName, projectUrl, overviewLines, teamEntries y extraLines.",
            "Si un campo falta, la app usa este contenido generico como respaldo."
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
