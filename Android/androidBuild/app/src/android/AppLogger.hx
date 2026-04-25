package android;

/**
 * AppLogger  ──  Log centralizado de la app.
 *
 * Uso:
 *   AppLogger.log("texto normal");
 *   AppLogger.warn("algo sospechoso");
 *   AppLogger.err("algo salió mal");
 *
 * También intercepta los trace() nativos de Haxe y los manda aquí.
 * La UI (MainView) se suscribe con AppLogger.onLine para mostrarlos
 * en la consola visual.
 *
 * NO tiene referencias a openfl/lime para que pueda usarse desde cualquier clase.
 */
class AppLogger {

    /** Callback que la UI registra para recibir líneas nuevas. */
    public static var onLine:String->Void = null;

    /** Buffer de líneas (máx. MAX_LINES) para que la UI pueda rehidratarse. */
    public static var lines(default, null):Array<String> = [];

    public static inline var MAX_LINES:Int = 300;

    static var _installed:Bool = false;

    // ─────────────────────────────────────────────────────────────────────────
    //  Instalación del interceptor de trace()
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Llama esto UNA sola vez al inicio (en Main o AndroidApp.onPreloadComplete).
     * A partir de ahí todos los trace() de Haxe llegan aquí.
     */
    public static function install():Void {
        if (_installed) return;
        _installed = true;

        haxe.Log.trace = function(v:Dynamic, ?info:haxe.PosInfos):Void {
            var prefix = "";
            #if debug
            if (info != null) {
                prefix = info.className.split(".").pop() + ":" + info.lineNumber + " | ";
            }
            #end
            AppLogger.log(prefix + Std.string(v));
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  API pública
    // ─────────────────────────────────────────────────────────────────────────

    public static function log(msg:String):Void {
        _push("[LOG] " + msg);
    }

    public static function warn(msg:String):Void {
        _push("[WRN] " + msg);
    }

    public static function err(msg:String):Void {
        _push("[ERR] " + msg);
    }

    /** Borra el buffer y notifica a la UI con cadena vacía (para que limpie). */
    public static function clear():Void {
        lines = [];
        if (onLine != null) onLine("");
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Internos
    // ─────────────────────────────────────────────────────────────────────────

    static function _push(line:String):Void {
        if (line == null) return;

        // También al logcat de Android en builds de debug
        #if (android && debug)
        try { lime.system.System.print(line); } catch (_:Dynamic) {}
        #end

        // Buffer
        for (piece in line.split("\n")) {
            var clean = StringTools.trim(piece);
            if (clean == "") continue;
            lines.push(clean);
        }
        while (lines.length > MAX_LINES) lines.shift();

        // Notificar a la UI
        if (onLine != null) {
            try { onLine(line); } catch (_:Dynamic) {}
        }
    }
}
