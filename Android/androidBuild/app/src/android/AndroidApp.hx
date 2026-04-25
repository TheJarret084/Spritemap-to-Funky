package android;

import android.AppLogger;
import android.gestor.ImportadorMediaBackend;
import haxe.Timer;
import lime.system.System;
import lime.utils.Assets as LimeAssets;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Application;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

class AndroidApp {
    var host:Application;
    var mounted:Bool = false;

    public function new(host:Application) {
        this.host = host;

        // Instalar el interceptor de trace() lo antes posible.
        // A partir de aquí TODOS los trace() van a AppLogger y de ahí a la UI.
        AppLogger.install();
    }

    public function onWindowCreate():Void {
        #if android
        if (host.window != null) {
            host.window.width  = 720;
            host.window.height = 1280;
        }
        #end
    }

    public function onPreloadComplete():Void {
        if (mounted) return;

        // ── Crear carpetas de media en el primer inicio ───────────────────────
        //    Silencioso si ya existen; loguea si las crea.
        #if android
        ImportadorMediaBackend.ensureMediaDirectories();
        #end

        #if !android
        mount(new UnsupportedTargetView());
        return;
        #end

        Backend.resetWorkspace();

        var splashAsset = AppConfig.resolveAssetPath(AppConfig.SPLASH_ASSET_PATH);
        if (Assets.exists(splashAsset) || LimeAssets.exists(splashAsset)) {
            mount(new SplashView(splashAsset, function() {
                #if caros
                // ── Caros Edition ─────────────────────────────────────────────
                //   Solo activo con:  lime build android -D caros
                //   NO se dispara en builds normales ni en -debug.
                startCarosEdition();
                #else
                replaceWith(new MainView());
                #end
            }));
            return;
        }

        #if caros
        startCarosEdition();
        #else
        mount(new MainView());
        #end
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helpers de montaje
    // ─────────────────────────────────────────────────────────────────────────

    function mount(view:Sprite):Void {
        if (mounted) return;
        mounted = true;
        Lib.current.addChild(view);
    }

    function replaceWith(view:Sprite):Void {
        while (Lib.current.numChildren > 0)
            Lib.current.removeChildAt(Lib.current.numChildren - 1);
        mounted = false;
        mount(view);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Caros Edition  (solo compila con -D caros)
    // ─────────────────────────────────────────────────────────────────────────

    #if caros
    function startCarosEdition():Void {
        AppLogger.warn("Caros Edition activada.");

        var carosVideoAsset = AppConfig.resolveAssetPath(AppConfig.CAROS_VIDEO_ASSET);
        var destPath        = AppConfig.getCarosVideoPath();

        // Extraer el video del APK al storage interno si todavía no existe
        if (!sys.FileSystem.exists(destPath)) {
            var bytes = Assets.getBytes(carosVideoAsset);
            if (bytes == null) bytes = LimeAssets.getBytes(carosVideoAsset);
            if (bytes != null) {
                try {
                    var out = sys.io.File.write(destPath, true);
                    out.write(bytes);
                    out.close();
                } catch (_:Dynamic) {}
            }
        }

        if (sys.FileSystem.exists(destPath)) {
            try { System.openFile(destPath); } catch (_:Dynamic) {}
        }

        Timer.delay(function() {
            try {
                if (Lib.application != null && Lib.application.window != null)
                    Lib.application.window.alert(AppConfig.CAROS_DIALOG_MESSAGE, AppConfig.CAROS_DIALOG_TITLE);
            } catch (_:Dynamic) {}

            Timer.delay(function() {
                #if sys
                Sys.exit(0);
                #end
            }, 450);

        }, AppConfig.CAROS_VIDEO_DURATION_MS);
    }
    #end
}

// ─────────────────────────────────────────────────────────────────────────────
//  Vista de plataforma no soportada
// ─────────────────────────────────────────────────────────────────────────────

class UnsupportedTargetView extends Sprite {
    public function new() {
        super();

        var text = new TextField();
        AppFonts.applyUi(text, 20, 0xFFFFFF, true);
        text.selectable = false;
        text.multiline  = true;
        text.wordWrap   = true;
        text.width      = 420;
        text.height     = 120;
        text.text       = "Este build está hecho sólo para Android.";
        text.x = 40;
        text.y = 80;
        addChild(text);
    }
}
