package android;

import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;

class SplashView extends Sprite {
    var background:Shape;
    var image:Bitmap;
    var onFinish:Void->Void;
    var finished:Bool = false;
    var startTime:Int = -1;

    public function new(assetPath:String, onFinish:Void->Void) {
        super();

        this.onFinish = onFinish;

        background = new Shape();
        addChild(background);

        var bitmapData:BitmapData = Assets.getBitmapData(assetPath);
        image = new Bitmap(bitmapData);
        image.smoothing = true;
        addChild(image);

        alpha = 0;
        buttonMode = true;
        useHandCursor = true;
        addEventListener(MouseEvent.CLICK, handleFinish);

        if (stage != null) init();
        else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    function onAddedToStage(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        init();
    }

    function init():Void {
        if (stage == null) return;

        startTime = Lib.getTimer();
        stage.addEventListener(Event.RESIZE, onResize);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        layout();
    }

    function onEnterFrame(_:Event):Void {
        var elapsed = Lib.getTimer() - startTime;
        var fade = AppConfig.SPLASH_FADE_MS;
        var total = AppConfig.SPLASH_DURATION_MS;

        if (elapsed < fade) {
            alpha = elapsed / fade;
        } else if (elapsed > total - fade) {
            alpha = 1 - ((elapsed - (total - fade)) / fade);
        } else {
            alpha = 1;
        }

        if (elapsed >= total) {
            finish();
        }
    }

    function onResize(_:Event):Void {
        layout();
    }

    function layout():Void {
        if (stage == null || image == null || image.bitmapData == null) return;

        var stageWidth = stage.stageWidth;
        var stageHeight = stage.stageHeight;
        var bitmapWidth = image.bitmapData.width;
        var bitmapHeight = image.bitmapData.height;
        var scale = Math.min(stageWidth / bitmapWidth, stageHeight / bitmapHeight);

        background.graphics.clear();
        background.graphics.beginFill(AppConfig.BACKGROUND_COLOR);
        background.graphics.drawRect(0, 0, stageWidth, stageHeight);
        background.graphics.endFill();

        image.scaleX = scale;
        image.scaleY = scale;
        image.x = (stageWidth - (bitmapWidth * scale)) * 0.5;
        image.y = (stageHeight - (bitmapHeight * scale)) * 0.5;
    }

    function handleFinish(_:MouseEvent):Void {
        finish();
    }

    function finish():Void {
        if (finished) return;
        finished = true;

        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        removeEventListener(MouseEvent.CLICK, handleFinish);
        if (stage != null) stage.removeEventListener(Event.RESIZE, onResize);
        if (onFinish != null) onFinish();
    }
}
