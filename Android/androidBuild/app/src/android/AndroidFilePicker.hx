package android;

#if android
import lime.system.JNI;
#end

class AndroidFilePicker {
    #if android
    static var registered:Bool = false;
    static var registerCallback:(Dynamic)->Void;
    static var browseFile:(String, String)->Void;
    static var saveFileToUser:(String, String, String)->Void;
    static var getWorkspaceRootBridge:Void->String;
    static var clearWorkspaceBridge:Void->Void;
    static var callbackBridge = new AndroidFilePickerCallback();
    #end

    public static function openFile(title:String, filter:String, onComplete:String->Void, onError:String->Void):Bool {
        #if android
        ensureInitialized();
        if (browseFile == null) {
            onError("El explorador del teléfono no está disponible.");
            return false;
        }

        callbackBridge.setHandlers(onComplete, onError);

        try {
            browseFile(title, normalizeFilter(filter));
            return true;
        } catch (error:Dynamic) {
            callbackBridge.clearHandlers();
            onError("No pude abrir el explorador del teléfono: " + Std.string(error));
            return false;
        }
        #else
        onError("AndroidFilePicker sólo existe en Android.");
        return false;
        #end
    }

    public static function saveFile(title:String, suggestedName:String, sourcePath:String, onComplete:String->Void, onError:String->Void):Bool {
        #if android
        ensureInitialized();
        if (saveFileToUser == null) {
            onError("Guardar archivo no está disponible.");
            return false;
        }

        callbackBridge.setHandlers(onComplete, onError);

        try {
            saveFileToUser(title, suggestedName, sourcePath);
            return true;
        } catch (error:Dynamic) {
            callbackBridge.clearHandlers();
            onError("No pude abrir el selector para guardar: " + Std.string(error));
            return false;
        }
        #else
        onError("Guardar archivo sólo existe en Android.");
        return false;
        #end
    }

    public static function getWorkspaceRoot():String {
        #if android
        ensureInitialized();
        if (getWorkspaceRootBridge == null) return "";

        try {
            return getWorkspaceRootBridge();
        } catch (_:Dynamic) {
            return "";
        }
        #else
        return "";
        #end
    }

    public static function clearWorkspace():Void {
        #if android
        ensureInitialized();
        if (clearWorkspaceBridge == null) return;

        try {
            clearWorkspaceBridge();
        } catch (_:Dynamic) {}
        #end
    }

    #if android
    static function ensureInitialized():Void {
        if (registered) return;
        registered = true;

        registerCallback = JNI.createStaticMethod(
            "org/haxe/extension/AndroidFilePicker",
            "setCallback",
            "(Lorg/haxe/lime/HaxeObject;)V",
            false,
            true
        );
        browseFile = JNI.createStaticMethod(
            "org/haxe/extension/AndroidFilePicker",
            "browseFile",
            "(Ljava/lang/String;Ljava/lang/String;)V",
            false,
            true
        );
        saveFileToUser = JNI.createStaticMethod(
            "org/haxe/extension/AndroidFilePicker",
            "saveFileToUser",
            "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
            false,
            true
        );
        getWorkspaceRootBridge = JNI.createStaticMethod(
            "org/haxe/extension/AndroidFilePicker",
            "getWorkspaceRoot",
            "()Ljava/lang/String;",
            false,
            true
        );
        clearWorkspaceBridge = JNI.createStaticMethod(
            "org/haxe/extension/AndroidFilePicker",
            "clearWorkspace",
            "()V",
            false,
            true
        );

        if (registerCallback != null) {
            registerCallback(callbackBridge);
        }
    }

    static function normalizeFilter(filter:String):String {
        if (filter == null) return "";
        var clean = StringTools.trim(filter).toLowerCase();
        if (StringTools.startsWith(clean, "*.")) clean = clean.substr(2);
        return clean;
    }
    #end
}

#if android
class AndroidFilePickerCallback implements lime.system.JNI.JNISafety {
    var onComplete:String->Void;
    var onError:String->Void;

    public function new() {}

    public function setHandlers(onComplete:String->Void, onError:String->Void):Void {
        this.onComplete = onComplete;
        this.onError = onError;
    }

    public function clearHandlers():Void {
        onComplete = null;
        onError = null;
    }

    @:runOnMainThread
    public function onPathSelected(path:String):Void {
        var complete = onComplete;
        clearHandlers();
        if (complete != null) complete(path);
    }

    @:runOnMainThread
    public function onFileSaved(path:String):Void {
        var complete = onComplete;
        clearHandlers();
        if (complete != null) complete(path);
    }

    @:runOnMainThread
    public function onPickerCancelled():Void {
        clearHandlers();
    }

    @:runOnMainThread
    public function onPickerError(message:String):Void {
        var errorHandler = onError;
        clearHandlers();
        if (errorHandler != null) errorHandler(message);
    }
}
#end
