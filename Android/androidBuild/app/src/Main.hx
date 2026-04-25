package;

import android.AndroidApp;
import android.api.DiscordRpcService;
import openfl.display.Application;

class Main extends Application {
    var androidApp:AndroidApp;
    var discordRpc:DiscordRpcService;

    public function new() {
        super();
        androidApp = new AndroidApp(this);
        discordRpc = new DiscordRpcService(this);
    }

    override public function onWindowCreate():Void {
        super.onWindowCreate();
        androidApp.onWindowCreate();
    }

    override public function onPreloadComplete():Void {
        super.onPreloadComplete();
        androidApp.onPreloadComplete();
        discordRpc.init();
    }
}
