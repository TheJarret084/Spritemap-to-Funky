package fp.ui;

import lime.utils.Assets as LimeAssets;
import openfl.Assets;
import android.AppConfig;

class XmlLayout {
    public static function loadAsset(path:String):Xml {
        var assetPath = AppConfig.resolveAssetPath(path);
        var raw:String = null;

        try {
            if (Assets.exists(assetPath)) raw = Assets.getText(assetPath);
            else if (LimeAssets.exists(assetPath)) raw = LimeAssets.getText(assetPath);
        } catch (_:Dynamic) {}

        if (raw == null || StringTools.trim(raw) == "") {
            throw 'No pude cargar el XML de UI: ' + path;
        }

        var parsed = Xml.parse(raw);
        for (node in parsed.elements()) return node;
        throw 'El XML de UI no tiene un nodo raíz válido: ' + path;
    }

    public static function children(node:Xml, ?name:String):Array<Xml> {
        var out:Array<Xml> = [];
        if (node == null) return out;
        for (child in node.elements()) {
            if (name == null || child.nodeName == name) out.push(child);
        }
        return out;
    }

    public static function attrString(node:Xml, name:String, fallback:String = ""):String {
        if (node == null || !node.exists(name)) return fallback;
        var v = node.get(name);
        return v == null ? fallback : v;
    }

    public static function attrFloat(node:Xml, name:String, fallback:Float = 0):Float {
        var v = attrString(node, name, null);
        if (v == null || StringTools.trim(v) == "") return fallback;
        var parsed = Std.parseFloat(v);
        return Math.isNaN(parsed) ? fallback : parsed;
    }

    public static function attrInt(node:Xml, name:String, fallback:Int = 0):Int {
        var v = attrString(node, name, null);
        if (v == null || StringTools.trim(v) == "") return fallback;
        var parsed = Std.parseInt(v);
        return parsed == null ? fallback : parsed;
    }

    public static function attrBool(node:Xml, name:String, fallback:Bool = false):Bool {
        var v = attrString(node, name, null);
        if (v == null) return fallback;
        var text = StringTools.trim(v).toLowerCase();
        return text == "true" || text == "1" || text == "yes" || text == "on";
    }

    public static function parseColor(text:String, fallback:Int):Int {
        if (text == null) return fallback;
        var clean = StringTools.trim(text);
        if (clean == "") return fallback;
        if (StringTools.startsWith(clean, "0x")) clean = clean.substr(2);
        if (StringTools.startsWith(clean, "#")) clean = clean.substr(1);
        try {
            var parsed = Std.parseInt("0x" + clean);
            return parsed == null ? fallback : parsed;
        } catch (_:Dynamic) {
            return fallback;
        }
    }
}
