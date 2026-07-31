package fp;

import android.AppConfig;
import android.AppFonts;
import android.AppLogger;
import android.AppModel.AnimationChoice;
import android.AppModel.ProjectPaths;
import android.Backend;
import android.ConsoleView;
import android.UiComponents.AnimationListView;
import android.UiComponents.CardSection;
import android.UiComponents.UiBrowseMode;
import android.UiComponents.UiButton;
import android.UiComponents.UiInput;
import fp.backend.FunkierPacherBackend;
import fp.ui.XmlLayout;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;

class FPMainView extends Sprite {
    static inline var BREAKPOINT_WIDE:Float = 900.0;
    static inline var MIN_MARGIN:Float = 16.0;
    static inline var MAX_CONTENT_W:Float = 1180.0;

    var layout:Xml;
    var paths:ProjectPaths;
    var onBack:Void->Void;

    var background:Shape;
    var accent:Shape;
    var uiLayer:Sprite;

    var titleField:TextField;
    var subtitleField:TextField;
    var footerField:TextField;

    var cardMap:Map<String, CardSection>;
    var inputMap:Map<String, UiInput>;
    var buttonMap:Map<String, UiButton>;
    var labelMap:Map<String, TextField>;

    var listView:AnimationListView;
    var consoleView:ConsoleView;

    var statusField:TextField;
    var selectionField:TextField;

    var scrollOffset:Float = 0;
    var maxScroll:Float = 0;
    var scrollPressY:Float = 0;
    var scrollAtPress:Float = 0;
    var scrolling:Bool = false;
    var scrollWasDragged:Bool = false;

    public function new(?onBack:Void->Void) {
        this.onBack = onBack;
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
        }

        paths = Backend.createDefaultPaths();
        if (paths.outputDir == null || StringTools.trim(paths.outputDir) == "") {
            paths.outputDir = Backend.getProcessingOutputDir();
        }

        cardMap = new Map();
        inputMap = new Map();
        buttonMap = new Map();
        labelMap = new Map();

        layout = XmlLayout.loadAsset("assets/ui/funkier_pacher.xml");

        buildBackground();
        uiLayer = new Sprite();
        addChild(uiLayer);
        buildFromLayout();
        bindActions();
        bindScreenScroll();
        refreshFromPaths();
        layoutUi();
        describeProject();
    }

    function buildBackground():Void {
        background = new Shape();
        addChild(background);

        accent = new Shape();
        addChild(accent);

        redrawBackground();

        if (stage != null) {
            stage.addEventListener(Event.RESIZE, function(_) {
                redrawBackground();
                layoutUi();
            });
        }
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
        for (node in XmlLayout.children(layout)) {
            addNode(uiLayer, node);
        }

        titleField = labelMap.get("title");
        subtitleField = labelMap.get("subtitle");
        footerField = labelMap.get("footer");
        statusField = labelMap.get("outputHint");

        if (titleField == null) titleField = makeFallbackLabel("Funkier-Pacher FP", 24, 18, 30, true, AppConfig.COLOR_TEXT);
        if (subtitleField == null) subtitleField = makeFallbackLabel("UI controlada por XML", 24, 52, 14, false, AppConfig.COLOR_MUTED);
        if (footerField == null) footerField = makeFallbackLabel("© 2026 Jarret Labs", 24, 740, 12, false, AppConfig.COLOR_MUTED);

        if (statusField == null) {
            statusField = makeFallbackLabel("Listo.", 24, 740, 13, false, AppConfig.COLOR_MUTED);
        }

        if (listView != null) {
            listView.onSelectionChanged = updateSelectionCount;
        }

        if (consoleView != null) {
            consoleView.setSize(consoleView.width, consoleView.height);
        }
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
                cardMap.set(XmlLayout.attrString(node, "id", XmlLayout.attrString(node, "title", "")), section);
                for (child in node.elements()) {
                    addNode(cast section.content, child, 0, 0);
                }

            case "input":
                var browse = XmlLayout.attrString(node, "browse", "file").toLowerCase();
                var mode = switch (browse) {
                    case "none": UiBrowseMode.NONE;
                    case "directory": UiBrowseMode.OPEN_DIRECTORY;
                    default: UiBrowseMode.OPEN_FILE;
                };
                var input = new UiInput(
                    XmlLayout.attrString(node, "label", XmlLayout.attrString(node, "id", "Input")),
                    XmlLayout.attrString(node, "hint", ""),
                    mode,
                    XmlLayout.attrString(node, "filter", null),
                    XmlLayout.attrString(node, "label", XmlLayout.attrString(node, "id", "Input"))
                );
                var iw = XmlLayout.attrFloat(node, "w", 320);
                input.setWidth(iw);
                input.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                input.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(input);
                var inputId = XmlLayout.attrString(node, "id", "");
                if (inputId != "") inputMap.set(inputId, input);

            case "button":
                var btn = new UiButton(XmlLayout.attrString(node, "text", XmlLayout.attrString(node, "id", "Button")));
                btn.setSize(XmlLayout.attrFloat(node, "w", 180), XmlLayout.attrFloat(node, "h", 48));
                btn.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                btn.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(btn);
                var btnId = XmlLayout.attrString(node, "id", "");
                if (btnId != "") buttonMap.set(btnId, btn);

            case "list":
                listView = new AnimationListView();
                listView.setSize(XmlLayout.attrFloat(node, "w", 860), XmlLayout.attrFloat(node, "h", 120));
                listView.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                listView.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(listView);
                var listId = XmlLayout.attrString(node, "id", "");
                if (listId != "") labelMap.set(listId, null);

            case "console":
                consoleView = new ConsoleView();
                consoleView.setSize(XmlLayout.attrFloat(node, "w", 860), XmlLayout.attrFloat(node, "h", 120));
                consoleView.x = offsetX + XmlLayout.attrFloat(node, "x", 0);
                consoleView.y = offsetY + XmlLayout.attrFloat(node, "y", 0);
                parent.addChild(consoleView);
                var consoleId = XmlLayout.attrString(node, "id", "");
                if (consoleId != "") labelMap.set(consoleId, null);

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
        uiLayer.addChild(tf);
        return tf;
    }

    function layoutUi():Void {
        if (uiLayer == null) return;

        var stageW = stage != null ? stage.stageWidth : 980.0;
        var stageH = stage != null ? stage.stageHeight : 720.0;
        var margin = clampFloat(stageW * 0.035, MIN_MARGIN, 32.0);
        var contentW = Math.min(MAX_CONTENT_W, Math.max(320.0, stageW - margin * 2.0));
        var left = Math.max(margin, (stageW - contentW) * 0.5);
        var top = margin + 4.0;
        var gap = contentW >= BREAKPOINT_WIDE ? 16.0 : 12.0;
        var wide = contentW >= BREAKPOINT_WIDE;

        uiLayer.x = 0;
        uiLayer.scaleX = 1;
        uiLayer.scaleY = 1;

        if (titleField != null) {
            titleField.x = left;
            titleField.y = top;
        }
        if (subtitleField != null) {
            subtitleField.x = left;
            subtitleField.y = top + 36;
            subtitleField.width = Math.max(180, contentW - 160);
            subtitleField.height = 22;
        }
        var backBtn = buttonMap.get("backBtn");
        if (backBtn != null) {
            var backW = wide ? 128.0 : 104.0;
            backBtn.setSize(backW, 42);
            backBtn.x = left + contentW - backW;
            backBtn.y = top + 2;
        }

        var y = top + 72;
        if (wide) {
            var colW = (contentW - gap) * 0.5;
            layoutPanel("project", left, y, colW, 284);
            layoutPanel("actions", left + colW + gap, y, colW, 284);
            layoutProjectContent(colW - 36, false);
            layoutActionsContent(colW - 36);

            y += 284 + gap;
            var remaining = Math.max(260.0, stageH - y - margin - 26.0);
            var animationsH = clampFloat(remaining * 0.58, 178.0, 280.0);
            var consoleH = Math.max(126.0, remaining - animationsH - gap);
            layoutPanel("animations", left, y, contentW, animationsH);
            layoutAnimationsContent(contentW - 36, animationsH - 74, false);
            y += animationsH + gap;
            layoutPanel("console", left, y, contentW, consoleH);
            layoutConsoleContent(contentW - 36, consoleH - 74);
            y += consoleH + 12;
        } else {
            layoutPanel("project", left, y, contentW, 260);
            layoutProjectContent(contentW - 36, true);
            y += 260 + gap;

            layoutPanel("actions", left, y, contentW, 228);
            layoutActionsContent(contentW - 36);
            y += 228 + gap;

            layoutPanel("animations", left, y, contentW, 250);
            layoutAnimationsContent(contentW - 36, 176, true);
            y += 250 + gap;

            layoutPanel("console", left, y, contentW, 150);
            layoutConsoleContent(contentW - 36, 76);
            y += 150 + 12;
        }

        if (footerField != null) {
            footerField.x = left;
            footerField.y = Math.max(y, stageH - margin - 20);
            updateScrollBounds(footerField.y + footerField.textHeight + margin);
        } else {
            updateScrollBounds(y + margin);
        }
    }

    function layoutPanel(id:String, x:Float, y:Float, w:Float, h:Float):Void {
        var panel = cardMap.get(id);
        if (panel == null) return;
        panel.x = x;
        panel.y = y;
        panel.setSize(w, h);
    }

    function layoutProjectContent(innerW:Float, compact:Bool):Void {
        var rowGap = compact ? 64.0 : 74.0;
        layoutInput("atlasPng", 0, 0, innerW, compact);
        layoutInput("animsXml", 0, rowGap, innerW, compact);
        layoutInput("outputDir", 0, rowGap * 2, innerW, compact);
    }

    function layoutActionsContent(innerW:Float):Void {
        if (statusField != null) {
            statusField.x = 0;
            statusField.y = 0;
            statusField.width = innerW;
            statusField.height = 42;
            statusField.wordWrap = true;
            statusField.multiline = true;
        }

        var buttonGap = 10.0;
        var primaryY = 58.0;
        var secondaryY = 124.0;
        var primaryW = (innerW - buttonGap) * 0.5;
        layoutButton("loadBtn", 0, primaryY, primaryW, 54);
        layoutButton("exportBtn", primaryW + buttonGap, primaryY, primaryW, 54);

        var smallW = (innerW - buttonGap * 2.0) / 3.0;
        layoutButton("allBtn", 0, secondaryY, smallW, 42);
        layoutButton("noneBtn", smallW + buttonGap, secondaryY, smallW, 42);
        layoutButton("clearBtn", (smallW + buttonGap) * 2.0, secondaryY, smallW, 42);
    }

    function layoutAnimationsContent(innerW:Float, innerH:Float, compact:Bool):Void {
        layoutInput("filter", 0, 0, innerW, compact);
        if (listView != null) {
            listView.x = 0;
            listView.y = compact ? 66 : 72;
            listView.setSize(innerW, Math.max(86, innerH - listView.y));
        }
    }

    function layoutConsoleContent(innerW:Float, innerH:Float):Void {
        if (consoleView == null) return;
        consoleView.x = 0;
        consoleView.y = 0;
        consoleView.setSize(innerW, Math.max(58, innerH));
    }

    function layoutInput(id:String, x:Float, y:Float, w:Float, compact:Bool):Void {
        var input = inputMap.get(id);
        if (input == null) return;
        input.x = x;
        input.y = y;
        input.setCompact(compact);
        input.setWidth(w);
    }

    function layoutButton(id:String, x:Float, y:Float, w:Float, h:Float):Void {
        var button = buttonMap.get(id);
        if (button == null) return;
        button.x = x;
        button.y = y;
        button.setSize(w, h);
    }

    static function clampFloat(value:Float, minValue:Float, maxValue:Float):Float {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }

    function bindActions():Void {
        bindButton("loadBtn", function() describeProject());
        bindButton("exportBtn", function() exportProject());
        bindButton("allBtn", function() setAllSelected(true));
        bindButton("noneBtn", function() setAllSelected(false));
        bindButton("clearBtn", function() AppLogger.clear());
        bindButton("backBtn", function() { if (onBack != null) onBack(); });

        bindFilter("filter");
        bindPathField("atlasPng", false);
        bindPathField("animsXml", false);
        bindPathField("outputDir", false);
    }

    function bindButton(id:String, cb:Void->Void):Void {
        var btn = buttonMap.get(id);
        if (btn != null) {
            btn.onPressed(function() {
                if (scrollWasDragged) {
                    scrollWasDragged = false;
                    return;
                }
                cb();
            });
        }
    }

    function bindScreenScroll():Void {
        if (uiLayer == null || stage == null) return;
        uiLayer.addEventListener(MouseEvent.MOUSE_WHEEL, onScreenWheel);
        uiLayer.addEventListener(MouseEvent.MOUSE_DOWN, onScreenMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onScreenMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onScreenMouseUp);
    }

    function onScreenWheel(event:MouseEvent):Void {
        if (maxScroll <= 0) return;
        scrollOffset -= event.delta * 28;
        applyScreenScroll();
    }

    function onScreenMouseDown(event:MouseEvent):Void {
        scrollWasDragged = false;
        if (maxScroll <= 0 || shouldKeepEventLocal(event.target)) return;
        scrolling = true;
        scrollPressY = event.stageY;
        scrollAtPress = scrollOffset;
    }

    function onScreenMouseMove(event:MouseEvent):Void {
        if (!scrolling) return;
        var delta = event.stageY - scrollPressY;
        if (Math.abs(delta) > 8) scrollWasDragged = true;
        scrollOffset = scrollAtPress - delta;
        applyScreenScroll();
    }

    function onScreenMouseUp(_:MouseEvent):Void {
        scrolling = false;
    }

    function shouldKeepEventLocal(target:Dynamic):Bool {
        if (target == null || !Std.isOfType(target, DisplayObject)) return false;
        var node:DisplayObject = cast target;
        while (node != null) {
            if (Std.isOfType(node, UiInput) || Std.isOfType(node, AnimationListView) || Std.isOfType(node, ConsoleView)) {
                return true;
            }
            node = node.parent;
        }
        return false;
    }

    function updateScrollBounds(contentBottom:Float):Void {
        var stageH = stage != null ? stage.stageHeight : 720.0;
        maxScroll = Math.max(0, contentBottom - stageH);
        applyScreenScroll();
    }

    function applyScreenScroll():Void {
        if (scrollOffset < 0) scrollOffset = 0;
        if (scrollOffset > maxScroll) scrollOffset = maxScroll;
        if (uiLayer != null) uiLayer.y = -scrollOffset;
    }

    function bindFilter(id:String):Void {
        var input = inputMap.get(id);
        if (input == null || input.field == null) return;
        input.field.addEventListener(Event.CHANGE, function(_) {
            if (listView != null) listView.setFilter(input.text);
            updateSelectionCount();
        });
    }

    function bindPathField(id:String, rebuildOnChange:Bool):Void {
        var input = inputMap.get(id);
        if (input == null || input.field == null) return;
        input.field.addEventListener(Event.CHANGE, function(_) {
            syncPathsFromFields();
            if (rebuildOnChange) describeProject();
        });
    }

    function refreshFromPaths():Void {
        setInputText("outputDir", paths.outputDir);
    }

    function setInputText(id:String, value:String):Void {
        var input = inputMap.get(id);
        if (input != null) input.text = value == null ? "" : value;
    }

    function syncPathsFromFields():Void {
        paths.animationJson = getInputText("animationJson");
        paths.atlasJson = getInputText("atlasJson");
        paths.atlasPng = getInputText("atlasPng");
        paths.animsXml = getInputText("animsXml");
        paths.atlasJson = paths.animsXml;
        paths.animsJson = getInputText("animsJson");
        paths.outputDir = getInputText("outputDir");
    }

    function getInputText(id:String):String {
        var input = inputMap.get(id);
        return input != null ? input.text : "";
    }

    function describeProject():Void {
        syncPathsFromFields();
        var result = FunkierPacherBackend.describe(paths);
        if (result == null) return;

        if (result.log != null && StringTools.trim(result.log) != "") {
            AppLogger.log(result.log);
        }

        if (result.animations != null) {
            if (listView != null) {
                listView.setItems(result.animations);
                listView.setFilter(getInputText("filter"));
            }
            if (statusField != null) statusField.text = 'Animaciones cargadas: ' + result.animations.length;
        }

        updateSelectionCount();
    }

    function exportProject():Void {
        syncPathsFromFields();
        var chosen = listView != null ? listView.getSelectedItems() : [];
        if (chosen.length == 0) {
            AppLogger.err("Selecciona al menos una animación.");
            if (statusField != null) statusField.text = "No hay animaciones seleccionadas.";
            return;
        }

        var result = FunkierPacherBackend.export(paths, chosen, true);
        if (result.log != null && StringTools.trim(result.log) != "") {
            AppLogger.log(result.log);
        }

        if (result.archivePath != null && StringTools.trim(result.archivePath) != "") {
            AppLogger.log("ZIP final: " + result.archivePath);
        }

        if (result.outputDir != null && StringTools.trim(result.outputDir) != "") {
            paths.outputDir = result.outputDir;
            setInputText("outputDir", result.outputDir);
        }

        if (statusField != null) statusField.text = 'Exportadas ' + result.filesWritten + ' tira(s).';
    }

    function setAllSelected(value:Bool):Void {
        if (listView != null) listView.setAllSelected(value);
        updateSelectionCount();
    }

    function updateSelectionCount():Void {
        if (selectionField == null) {
            selectionField = makeFallbackLabel("", 0, 0, 12, false, AppConfig.COLOR_MUTED);
            selectionField.visible = false;
        }

        var total = listView != null ? listView.getSelectedItems().length : 0;
        var text = 'Seleccionadas: ' + total;
        if (statusField != null) {
            statusField.text = text;
        }
        selectionField.text = text;
    }
}
