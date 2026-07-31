package;

import android.AppConfig;
import android.AppFonts;
import android.AppLogger;
import android.AndroidApp;
import android.Backend;
import android.ConsoleView;
import android.ProjectInfoOverlay;
import android.ProjectNavbar;
import android.UiComponents.CardSection;
import android.UiComponents.UiButton;
import fp.ui.XmlLayout;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class MainRouter extends Sprite {
    static inline var MODE_MENU:Int = 0;
    static inline var MODE_SPRITEMAP:Int = 1;
    static inline var MODE_FUNKIER:Int = 2;

    var background:Shape;
    var accent:Shape;
    var titleField:TextField;
    var subtitleField:TextField;
    var footerField:TextField;

    var menuLayout:Xml;
    var panelMap:Map<String, CardSection>;
    var buttonMap:Map<String, UiButton>;
    var labelMap:Map<String, TextField>;

    var currentMode:Int = MODE_MENU;
    var currentScreen:Sprite;
    var menuLayer:Sprite;
    var menuItems:Array<DisplayObject>;

    static inline var MIN_MARGIN:Float = 16.0;
    static inline var MENU_BREAKPOINT:Float = 820.0;

    public function new() {
        super();
        if (stage != null) init();
        else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    function onAddedToStage(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        init();
    }

    function init():Void {
        if (stage != null) {
            stage.scaleMode = openfl.display.StageScaleMode.NO_SCALE;
            stage.align = openfl.display.StageAlign.TOP_LEFT;
            stage.color = AppConfig.BACKGROUND_COLOR;
            stage.addEventListener(Event.RESIZE, onResize);
        }

        panelMap = new Map();
        buttonMap = new Map();
        labelMap = new Map();
        menuLayout = XmlLayout.loadAsset("assets/ui/main.xml");

        buildBackground();
        menuLayer = new Sprite();
        addChild(menuLayer);
        menuItems = [];
        buildFromLayout();
        buildMenuActions();
        showMenu();
        layout();
    }

    function buildBackground():Void {
        background = new Shape();
        addChild(background);

        accent = new Shape();
        addChild(accent);
    }

    function redrawBackground():Void {
        var w = stage != null ? stage.stageWidth : 980;
        var h = stage != null ? stage.stageHeight : 720;

        background.graphics.clear();
        background.graphics.beginFill(AppConfig.BACKGROUND_COLOR, 1);
        background.graphics.drawRect(0, 0, w, h);
        background.graphics.endFill();

        accent.graphics.clear();
        accent.graphics.beginFill(AppConfig.COLOR_ACCENT_SOFT, 1);
        accent.graphics.drawRect(0, 0, w, 6);
        accent.graphics.endFill();
    }

    function buildFromLayout():Void {
        for (node in XmlLayout.children(menuLayout)) {
            addNode(menuLayer, node);
        }

        titleField = labelMap.get("title");
        subtitleField = labelMap.get("subtitle");
        footerField = labelMap.get("footer");

        if (titleField == null) titleField = makeFallbackLabel("Spritemap to Funky", 24, 18, 30, true, AppConfig.COLOR_TEXT);
        if (subtitleField == null) subtitleField = makeFallbackLabel("Elegí una herramienta para abrir o volver al menú.", 24, 52, 14, false, AppConfig.COLOR_MUTED);
        if (footerField == null) footerField = makeFallbackLabel("© 2026 Jarret Labs", 24, 676, 12, false, AppConfig.COLOR_MUTED);
    }

    function addNode(parent:Sprite, node:Xml, ?offsetX:Float = 0, ?offsetY:Float = 0):Void {
        switch (node.nodeName) {
            case "panel":
                var section = new CardSection(XmlLayout.attrString(node, "title", XmlLayout.attrString(node, "id", "Panel")));
                var w = XmlLayout.attrFloat(node, "w", 320);
                var h = XmlLayout.attrFloat(node, "h", 220);
                section.setSize(w, h);
                section.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                section.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(section);
                menuItems.push(section);
                panelMap.set(XmlLayout.attrString(node, "id", XmlLayout.attrString(node, "title", "")), section);
                for (child in node.elements()) addNode(cast section.content, child, 0, 0);

            case "button":
                var btn = new UiButton(XmlLayout.attrString(node, "text", XmlLayout.attrString(node, "id", "Button")));
                btn.setSize(XmlLayout.attrFloat(node, "w", 180), XmlLayout.attrFloat(node, "h", 48));
                btn.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                btn.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(btn);
                menuItems.push(btn);
                var btnId = XmlLayout.attrString(node, "id", "");
                if (btnId != "") buttonMap.set(btnId, btn);

            case "text", "label":
                var tf = createLabel(
                    XmlLayout.attrString(node, "text", ""),
                    XmlLayout.attrInt(node, "size", 14),
                    XmlLayout.parseColor(XmlLayout.attrString(node, "color", null), AppConfig.COLOR_TEXT),
                    XmlLayout.attrBool(node, "bold", false)
                );
                tf.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                tf.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(tf);
                menuItems.push(tf);
                var textId = XmlLayout.attrString(node, "id", "");
                if (textId != "") labelMap.set(textId, tf);

            default:
                for (child in node.elements()) addNode(parent, child, offsetX, offsetY);
        }
    }

    function createLabel(text:String, size:Int, color:Int, bold:Bool):TextField {
        var tf = new TextField();
        tf.selectable = false;
        tf.mouseEnabled = false;
        tf.autoSize = TextFieldAutoSize.LEFT;
        tf.defaultTextFormat = new TextFormat(AppFonts.getUiFontName(bold), size, color, bold);
        tf.embedFonts = true;
        tf.text = text;
        return tf;
    }

    function makeFallbackLabel(text:String, x:Float, y:Float, size:Int, bold:Bool, color:Int):TextField {
        var tf = createLabel(text, size, color, bold);
        tf.x = x;
        tf.y = y;
        if (menuLayer != null) menuLayer.addChild(tf);
        else addChild(tf);
        return tf;
    }

    function showMenu():Void {
        showScreen(MODE_MENU);
    }

    function showScreen(mode:Int):Void {
        currentMode = mode;
        if (currentScreen != null && currentScreen.parent != null) currentScreen.parent.removeChild(currentScreen);
        currentScreen = null;

        if (menuLayer != null) menuLayer.visible = (mode == MODE_MENU);

        switch (mode) {
            case MODE_MENU:
                // Nada que crear: el menú ya está montado en menuLayer.
                null;

            case MODE_SPRITEMAP:
                currentScreen = new spritemap.SpritemapXmlView(function() showMenu());
                addChild(currentScreen);

            case MODE_FUNKIER:
                currentScreen = new fp.FPMainView(function() showMenu());
                addChild(currentScreen);
        }

        layout();
    }

    function buildMenuActions():Void {
        if (buttonMap.exists("spritemapBtn")) bindButton("spritemapBtn", function() showScreen(MODE_SPRITEMAP));
        if (buttonMap.exists("funkierBtn")) bindButton("funkierBtn", function() showScreen(MODE_FUNKIER));
        if (buttonMap.exists("clearBtn")) bindButton("clearBtn", function() AppLogger.clear());
    }

    function bindButton(id:String, cb:Void->Void):Void {
        var btn = buttonMap.get(id);
        if (btn != null) btn.onPressed(cb);
    }

    function onResize(_:Event):Void {
        layout();
    }

    function layout():Void {
        redrawBackground();
        var stageW = stage != null ? stage.stageWidth : 980.0;
        var stageH = stage != null ? stage.stageHeight : 720.0;
        var margin = clampFloat(stageW * 0.035, MIN_MARGIN, 32.0);
        var contentW = Math.max(320.0, stageW - margin * 2.0);
        var left = margin;
        var top = margin + 4.0;

        if (titleField != null) {
            titleField.x = left;
            titleField.y = top;
        }
        if (subtitleField != null) {
            subtitleField.x = left;
            subtitleField.y = top + 34;
            subtitleField.width = contentW;
            subtitleField.height = 24;
        }
        layoutChooser(left, top + 74, contentW);
        if (footerField != null) {
            footerField.x = left;
            footerField.y = stageH - margin - 18;
        }
    }

    function layoutChooser(x:Float, y:Float, w:Float):Void {
        var panel = panelMap.get("chooser");
        if (panel == null) return;

        var stacked = w < MENU_BREAKPOINT;
        var panelH = stacked ? 292.0 : 184.0;
        panel.x = x;
        panel.y = y;
        panel.setSize(w, panelH);

        var innerW = panel.innerWidth;
        var gap = stacked ? 10.0 : 12.0;
        var buttonH = stacked ? 52.0 : 58.0;

        var spritemapBtn = buttonMap.get("spritemapBtn");
        var funkierBtn = buttonMap.get("funkierBtn");
        var clearBtn = buttonMap.get("clearBtn");

        if (stacked) {
            layoutMenuButton(spritemapBtn, 0, 0, innerW, buttonH);
            layoutMenuButton(funkierBtn, 0, buttonH + gap, innerW, buttonH);
            layoutMenuButton(clearBtn, 0, (buttonH + gap) * 2, innerW, buttonH);
            layoutMenuHint("hint", 0, (buttonH + gap) * 3 + 10, innerW, 20);
            layoutMenuHint("hint2", 0, (buttonH + gap) * 3 + 36, innerW, 42);
        } else {
            var clearW = 160.0;
            var primaryW = (innerW - clearW - gap * 2.0) * 0.5;
            layoutMenuButton(spritemapBtn, 0, 0, primaryW, buttonH);
            layoutMenuButton(funkierBtn, primaryW + gap, 0, primaryW, buttonH);
            layoutMenuButton(clearBtn, (primaryW + gap) * 2, 0, clearW, buttonH);
            layoutMenuHint("hint", 0, 82, innerW, 20);
            layoutMenuHint("hint2", 0, 108, innerW, 42);
        }
    }

    function layoutMenuButton(button:UiButton, x:Float, y:Float, w:Float, h:Float):Void {
        if (button == null) return;
        button.x = x;
        button.y = y;
        button.setSize(w, h);
    }

    function layoutMenuHint(id:String, x:Float, y:Float, w:Float, h:Float):Void {
        var tf = labelMap.get(id);
        if (tf == null) return;
        tf.x = x;
        tf.y = y;
        tf.width = w;
        tf.height = h;
        tf.wordWrap = true;
        tf.multiline = true;
    }

    static function clampFloat(value:Float, minValue:Float, maxValue:Float):Float {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }
}
