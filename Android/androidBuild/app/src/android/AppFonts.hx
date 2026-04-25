package android;

import lime.utils.Assets as LimeAssets;
import openfl.Assets;
import openfl.text.TextField;
import openfl.text.TextFormat;

class AppFonts {
    static inline var UI_REGULAR_PATH:String = "fonts/Terminus/TerminessNerdFontPropo-Regular.ttf";
    static inline var UI_BOLD_PATH:String    = "fonts/Terminus/TerminessNerdFontPropo-Bold.ttf";
    static inline var MONO_PATH:String       = "fonts/DepartureMono/DepartureMonoNerdFontMono-Regular.otf";

    static var uiRegularName:String;
    static var uiBoldName:String;
    static var monoName:String;

    public static function applyUi(field:TextField, size:Int, color:Int, ?bold:Bool = false):Void {
        apply(field, resolveUiName(bold), size, color, bold);
    }

    public static function applyMono(field:TextField, size:Int, color:Int, ?bold:Bool = false):Void {
        apply(field, resolveMonoName(), size, color, bold);
    }

    public static function getUiFontName(?bold:Bool = false):String {
        return resolveUiName(bold);
    }

    static function apply(field:TextField, fontName:String, size:Int, color:Int, bold:Bool):Void {
        field.embedFonts = true;
        field.defaultTextFormat = new TextFormat(fontName, size, color, bold);
    }

    static function resolveUiName(bold:Bool):String {
        if (bold) {
            if (uiBoldName == null) uiBoldName = loadFontName(UI_BOLD_PATH);
            return uiBoldName;
        }

        if (uiRegularName == null) uiRegularName = loadFontName(UI_REGULAR_PATH);
        return uiRegularName;
    }

    static function resolveMonoName():String {
        if (monoName == null) monoName = loadFontName(MONO_PATH);
        return monoName;
    }

    static function loadFontName(path:String):String {
        var assetPath = AppConfig.resolveAssetPath(path);
        var font:Dynamic = null;

        try {
            if (Assets.exists(assetPath)) font = Assets.getFont(assetPath);
            else if (LimeAssets.exists(assetPath)) font = LimeAssets.getFont(assetPath);
        } catch (_:Dynamic) {}

        if (font != null && font.fontName != null && StringTools.trim(font.fontName) != "") {
            return font.fontName;
        }

        return "_sans";
    }
}
