package android;

import haxe.Timer;
import lime.system.System;
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
    }

    public function onWindowCreate():Void {
        #if android
        if (host.window != null) {
            host.window.width = 720;
            host.window.height = 1280;
        }
        #end
    }

    public function onPreloadComplete():Void {
        if (mounted) return;

        #if !android
        mount(new UnsupportedTargetView());
        return;
        #end

        Backend.resetWorkspace();

        if (Assets.exists(AppConfig.SPLASH_ASSET_PATH)) {
            mount(new SplashView(AppConfig.SPLASH_ASSET_PATH, function() {
                #if caros
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

    function mount(view:Sprite):Void {
        if (mounted) return;
        mounted = true;
        Lib.current.addChild(view);
    }

    function replaceWith(view:Sprite):Void {
        while (Lib.current.numChildren > 0) {
            Lib.current.removeChildAt(Lib.current.numChildren - 1);
        }
        mounted = false;
        mount(view);
    }

    function startCarosEdition():Void {
        if (Assets.exists(AppConfig.CAROS_VIDEO_PATH)) {
            try {
                System.openFile(AppConfig.CAROS_VIDEO_PATH);
            } catch (_:Dynamic) {}
        }

        Timer.delay(function() {
            try {
                if (Lib.application != null && Lib.application.window != null) {
                    Lib.application.window.alert(AppConfig.CAROS_DIALOG_MESSAGE, AppConfig.CAROS_DIALOG_TITLE);
                }
            } catch (_:Dynamic) {}

            Timer.delay(function() {
                #if sys
                Sys.exit(0);
                #end
            }, 450);
        }, AppConfig.CAROS_VIDEO_DURATION_MS);
    }
}

class UnsupportedTargetView extends Sprite {
    public function new() {
        super();

        var text = new TextField();
        text.defaultTextFormat = new TextFormat("_sans", 20, 0xFFFFFF, true);
        text.selectable = false;
        text.multiline = true;
        text.wordWrap = true;
        text.width = 420;
        text.height = 120;
        text.text = "Este build está hecho sólo para Android.";
        text.x = 40;
        text.y = 80;
        addChild(text);
    }
}
