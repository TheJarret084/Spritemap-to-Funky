package stf;

import haxe.io.Path;

class PlatformFolders {
    public static inline var DESKTOP_ROOT_NAME:String = "STF-PC";
    public static inline var MEDIA_DIR_NAME:String = "media";
    public static inline var WORKSPACE_DIR_NAME:String = "workspace";

    public static function desktopRoot():String {
        #if sys
        return Path.join([Sys.getCwd(), DESKTOP_ROOT_NAME]);
        #else
        return DESKTOP_ROOT_NAME;
        #end
    }

    public static function desktopMediaRoot():String {
        return Path.join([desktopRoot(), MEDIA_DIR_NAME]);
    }

    public static function desktopWorkspaceRoot():String {
        return Path.join([desktopRoot(), WORKSPACE_DIR_NAME]);
    }

    public static function desktopSpritemapsDir():String {
        return Path.join([desktopMediaRoot(), "spritemaps"]);
    }

    public static function desktopProcessedDir():String {
        return Path.join([desktopMediaRoot(), "processed"]);
    }

    public static function desktopExportsDir():String {
        return Path.join([desktopMediaRoot(), "exports"]);
    }
}
