package android.api;

import backend.Exporter;
import backend.Tools;
import haxe.Json;

class Api {
    public static function describeProject(rawRequest:String):String {
        return run(rawRequest, Exporter.describeRequest);
    }

    public static function exportProject(rawRequest:String):String {
        return run(rawRequest, Exporter.exportRequest);
    }

    static function run(rawRequest:String, handler:Dynamic->Dynamic):String {
        try {
            var request = Json.parse(rawRequest);
            return Json.stringify(handler(request));
        } catch (error:Dynamic) {
            return Json.stringify(Tools.makeError("Error procesando solicitud: " + Std.string(error)));
        }
    }
}
