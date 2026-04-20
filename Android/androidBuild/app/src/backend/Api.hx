package backend;

import haxe.Json;

class Api {
    public static function describeProject(requestJson:String):String {
        try {
            var request = Json.parse(requestJson == null ? "{}" : requestJson);
            return Json.stringify(Exporter.describeRequest(request));
        } catch (error:Dynamic) {
            return Json.stringify(Tools.makeError("Describe falló: " + Std.string(error)));
        }
    }

    public static function exportProject(requestJson:String):String {
        try {
            var request = Json.parse(requestJson == null ? "{}" : requestJson);
            return Json.stringify(Exporter.exportRequest(request));
        } catch (error:Dynamic) {
            return Json.stringify(Tools.makeError("Export falló: " + Std.string(error)));
        }
    }
}
