package;

import android.AndroidApp;
import openfl.display.Application;

class Main extends Application {
    var androidApp:AndroidApp;

    public function new() {
        super();
        androidApp = new AndroidApp(this);
    }

    override public function onWindowCreate():Void {
        super.onWindowCreate();
        androidApp.onWindowCreate();
    }

    override public function onPreloadComplete():Void {
        super.onPreloadComplete();
        androidApp.onPreloadComplete();
    }
}
