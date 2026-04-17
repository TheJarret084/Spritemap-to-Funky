package;

#if cpp
import cpp.Lib;
import cpp.Prime;
#end

class Native {
    #if cpp
    static var fDescribe:Dynamic;
    static var fExport:Dynamic;
    static var loaded:Bool = false;
    #end

    public static function available():Bool {
        #if cpp
        ensureLoaded();
        return fDescribe != null && fExport != null;
        #else
        return false;
        #end
    }

    public static function describeProject(requestJson:String):String {
        #if cpp
        ensureLoaded();
        if (fDescribe == null) return '{"ok":false,"log":"backend_describe no está disponible."}';
        try {
            return fDescribe(requestJson);
        } catch (error:Dynamic) {
            return '{"ok":false,"log":"backend_describe lanzó error: ' + escapeJson(Std.string(error)) + '"}';
        }
        #else
        return '{"ok":false,"log":"Native.describeProject sólo existe en target cpp."}';
        #end
    }

    public static function exportProject(requestJson:String):String {
        #if cpp
        ensureLoaded();
        if (fExport == null) return '{"ok":false,"log":"backend_export no está disponible."}';
        try {
            return fExport(requestJson);
        } catch (error:Dynamic) {
            return '{"ok":false,"log":"backend_export lanzó error: ' + escapeJson(Std.string(error)) + '"}';
        }
        #else
        return '{"ok":false,"log":"Native.exportProject sólo existe en target cpp."}';
        #end
    }

    #if cpp
    static function ensureLoaded():Void {
        if (loaded) return;
        loaded = true;

        #if !android
        var binDir = Lib.getBinDirectory();
        Lib.pushDllSearchPath("ndll/" + binDir);
        Lib.pushDllSearchPath("app/ndll/" + binDir);
        Lib.pushDllSearchPath("./ndll/" + binDir);
        #end

        fDescribe = Prime.load("backend", "backend_describe", "ss", true);
        fExport = Prime.load("backend", "backend_export", "ss", true);
    }
    #end

    static function escapeJson(value:String):String {
        if (value == null) return "";
        var out = value;
        out = StringTools.replace(out, "\\", "\\\\");
        out = StringTools.replace(out, "\"", "\\\"");
        out = StringTools.replace(out, "\n", "\\n");
        out = StringTools.replace(out, "\r", "\\r");
        return out;
    }
}
