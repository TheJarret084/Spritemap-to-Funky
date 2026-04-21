package android;

class AppConfig {
    public static inline var APP_TITLE:String = "Spritemap to Funky";
    public static inline var APP_SUBTITLE:String = "Convierte el spritemap en frames y guarda el resultado como ZIP.";
    public static inline var SPLASH_ASSET_PATH:String = "assets/other/cualeselproblema.jpg";
    public static inline var SPLASH_DURATION_MS:Int = 2200;
    public static inline var SPLASH_FADE_MS:Int = 360;
    public static inline var BACKGROUND_COLOR:Int = 0x050816;
    public static inline var PROCESSED_FOLDER:String = "processed";
    public static inline var EXPORTS_FOLDER:String = "exports";
    public static inline var SAVE_DIALOG_TITLE:String = "Guardar ZIP";

    // caros config
    #if android
    public static inline var CAROS_VIDEO_ASSET:String = "other/jejeje.mp4"; // nombre dentro de assets
    #end
    public static inline var CAROS_VIDEO_DURATION_MS:Int = 16000;
    public static inline var CAROS_DIALOG_TITLE:String = "Error Fatal";
    public static inline var CAROS_DIALOG_MESSAGE:String = "Se detecto un problema critico. La app se cerrara.";

    // Llama esto una vez que Lime ya inicio
    #if android
    public static function getCarosVideoPath():String {
        return lime.system.System.applicationStorageDirectory + "/jejeje.mp4";
    }
    #end
}