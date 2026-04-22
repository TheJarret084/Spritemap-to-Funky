package android;

import lime.utils.Assets as LimeAssets;
import openfl.Assets;

class AppConfig {
    public static inline var APP_TITLE:String = "Spritemap to Funky!";
    public static inline var APP_SUBTITLE:String = "Convierte el spritemap de Adove Animate en frames.";
    public static inline var SPLASH_ASSET_PATH:String = "other/cualeselproblema.jpg";
    public static inline var BROWSE_ICON_ASSET:String = "buttons/addFilesExport.png";
    public static inline var SPLASH_DURATION_MS:Int = 2200;
    public static inline var SPLASH_FADE_MS:Int = 360;
    public static inline var BACKGROUND_COLOR:Int = 0x050816;
    public static inline var SAVE_DIALOG_TITLE:String = "Guardar ZIP";
    public static inline var PACKAGE_NAME:String = "com.thejarretlabs.spritemaptofunky";

    // caros config
    #if android
    public static inline var CAROS_VIDEO_ASSET:String = "other/jejeje.mp4";
    #end
    public static inline var CAROS_VIDEO_DURATION_MS:Int = 16000;
    public static inline var CAROS_DIALOG_TITLE:String = "Error Fatal";
    public static inline var CAROS_DIALOG_MESSAGE:String = "Se detecto un problema critico. La app se cerrara.";

    public static function resolveAssetPath(path:String):String {
        if (path == null || StringTools.trim(path) == "") return path;

        var normalized = StringTools.startsWith(path, "assets/") ? path.substr("assets/".length) : path;
        var prefixed = StringTools.startsWith(path, "assets/") ? path : "assets/" + path;

        if (Assets.exists(normalized) || LimeAssets.exists(normalized)) return normalized;
        if (Assets.exists(prefixed) || LimeAssets.exists(prefixed)) return prefixed;

        return normalized;
    }

    // ─── Paths (llamar solo después de que Lime haya iniciado) ───

    #if android
    /** /data/data/com.app/files/ — privado, borrable */
    public static function getInternalDir():String {
        return lime.system.System.applicationStorageDirectory;
    }

    /** /sdcard/Android/media/com.app/ — visible al usuario, no necesita permisos extra */
    public static function getMediaDir():String {
        return "/sdcard/Android/media/" + PACKAGE_NAME + "/";
    }

    /** Donde el usuario verá sus ZIPs exportados */
    public static function getExportsDir():String {
        return getMediaDir() + "exports/";
    }

    /** Procesamiento temporal, interno */
    public static function getProcessedDir():String {
        return getInternalDir() + "processed/";
    }

    /** Video de caros edition, extraído al storage interno */
    public static function getCarosVideoPath():String {
        return getInternalDir() + "jejeje.mp4";
    }
    #end
}
