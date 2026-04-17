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
        if (fDescribe == null) {
            #if android
            return '{"ok":false,"log":"[ANDROID] backend_describe no está disponible. ¿Incluiste el backend correcto en ndll/Android?"}';
            #elseif linux
            return '{"ok":false,"log":"[LINUX] backend_describe no está disponible. Solo testea aquí, no producción."}';
            #else
            return '{"ok":false,"log":"[OTRO] backend_describe no está disponible."}';
            #end
        }
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
        if (fExport == null) {
            #if android
            return '{"ok":false,"log":"[ANDROID] backend_export no está disponible. ¿Incluiste el backend correcto en ndll/Android?"}';
            #elseif linux
            return '{"ok":false,"log":"[LINUX] backend_export no está disponible. Solo testea aquí, no producción."}';
            #else
            return '{"ok":false,"log":"[OTRO] backend_export no está disponible."}';
            #end
        }
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

        #if android
        // En Android, el backend debe estar en ndll/Android/arm64-v8a o ndll/Android/armeabi-v7a
        // No modificar search path, Lime lo maneja
        #elseif linux
        // Solo para test, nunca producción
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
