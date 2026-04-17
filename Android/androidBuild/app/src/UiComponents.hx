package;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import Model.AnimationChoice;

class AddFileButton extends Sprite {
    public function new(onClick:Void->Void) {
        super();
        var icon = new openfl.display.Bitmap(openfl.Assets.getBitmapData("assets/buttons/addFilesExport.png"));
        icon.width = 40;
        icon.height = 28;
        addChild(icon);
        buttonMode = true;
        useHandCursor = true;
        addEventListener(MouseEvent.CLICK, function(_) onClick());
    }
}

class CardSection extends Sprite {
    public var content:Sprite;
    public var innerWidth(default, null):Float = 0;
    public var innerHeight(default, null):Float = 0;

    var background:Shape;
    var titleField:TextField;

    public function new(title:String) {
        super();

        background = new Shape();
        addChild(background);

        titleField = new TextField();
        titleField.defaultTextFormat = new TextFormat("_sans", 20, 0xF9FAFB, true);
        titleField.selectable = false;
        titleField.mouseEnabled = false;
        titleField.text = title;
        addChild(titleField);

        content = new Sprite();
        addChild(content);
    }

    public function setSize(width:Float, height:Float):Void {
        background.graphics.clear();
        background.graphics.beginFill(0x0F172A, 0.94);
        background.graphics.drawRoundRect(0, 0, width, height, 28, 28);
        background.graphics.endFill();

        titleField.x = 18;
        titleField.y = 16;
        titleField.width = width - 36;
        titleField.height = 28;

        content.x = 18;
        content.y = 56;
        innerWidth = width - 36;
        innerHeight = height - 74;
    }
}

class UiButton extends Sprite {
    public var label(get, set):String;
    public var enabled(get, set):Bool;

    var background:Shape;
    var labelField:TextField;
    var fillColor:Int;
    var disabledColor:Int;
    var widthValue:Float = 0;
    var heightValue:Float = 0;
    var labelValue:String = "";
    var enabledValue:Bool = true;

    public function new(label:String, fillColor:Int = 0x2563EB) {
        super();
        this.fillColor = fillColor;
        this.disabledColor = 0x334155;

        buttonMode = true;
        useHandCursor = true;
        mouseChildren = false;

        background = new Shape();
        addChild(background);

        labelField = new TextField();
        labelField.defaultTextFormat = new TextFormat("_sans", 18, 0xFFFFFF, true);
        labelField.selectable = false;
        labelField.mouseEnabled = false;
        labelField.autoSize = TextFieldAutoSize.LEFT;
        addChild(labelField);

        addEventListener(MouseEvent.MOUSE_DOWN, function(_) {
            if (enabled) alpha = 0.92;
        });
        addEventListener(MouseEvent.MOUSE_UP, function(_) {
            alpha = enabled ? 1.0 : 0.6;
        });
        addEventListener(MouseEvent.ROLL_OUT, function(_) {
            alpha = enabled ? 1.0 : 0.6;
        });

        labelValue = label;
        setSize(220, 52);
        redraw();
    }

    public function setSize(width:Float, height:Float):Void {
        widthValue = width;
        heightValue = height;
        redraw();
    }

    function set_label(value:String):String {
        labelValue = value;
        if (labelField != null) {
            labelField.text = value;
            layoutLabel();
        }
        return value;
    }

    function set_enabled(value:Bool):Bool {
        enabledValue = value;
        mouseEnabled = value;
        alpha = value ? 1.0 : 0.6;
        redraw();
        return value;
    }

    function get_label():String {
        return labelValue;
    }

    function get_enabled():Bool {
        return enabledValue;
    }

    function redraw():Void {
        if (background == null) return;

        background.graphics.clear();
        background.graphics.beginFill(enabledValue ? fillColor : disabledColor);
        background.graphics.drawRoundRect(0, 0, widthValue, heightValue, 20, 20);
        background.graphics.endFill();

        labelField.text = labelValue;
        layoutLabel();
    }

    function layoutLabel():Void {
        labelField.x = (widthValue - labelField.textWidth) * 0.5 - 2;
        labelField.y = (heightValue - labelField.textHeight) * 0.5 - 4;
    }
}

class UiInput extends Sprite {
    var browseButton:openfl.display.SimpleButton;
    public var text(get, set):String;
    public var field(default, null):TextField;

    var labelField:TextField;
    var hintField:TextField;
    var background:Shape;
    var widthValue:Float = 0;

    public function new(label:String, hint:String = "") {
        super();

        labelField = new TextField();
        labelField.defaultTextFormat = new TextFormat("_sans", 15, 0xCBD5E1, true);
        labelField.selectable = false;
        labelField.mouseEnabled = false;
        labelField.text = label;
        addChild(labelField);

        background = new Shape();
        addChild(background);

        field = new TextField();
        field.type = TextFieldType.INPUT;
        field.defaultTextFormat = new TextFormat("_sans", 16, 0xE2E8F0);
        field.textColor = 0xE2E8F0;
        field.multiline = false;
        field.wordWrap = false;
        field.background = false;
        field.border = false;
        field.height = 30;
        addChild(field);

        hintField = new TextField();
        hintField.defaultTextFormat = new TextFormat("_sans", 12, 0x64748B);
        hintField.selectable = false;
        hintField.mouseEnabled = false;
        hintField.text = hint;
        addChild(hintField);

        browseButton = makeBrowseButton();
        addChild(browseButton);
        setWidth(320);
    }
    function makeBrowseButton():openfl.display.SimpleButton {
        var icon = new openfl.display.Bitmap(openfl.Assets.getBitmapData("assets/buttons/saveFilesExport.png"));
        icon.width = 40;
        icon.height = 28;
        var up = new Sprite();
        up.addChild(icon);
        var btn = new openfl.display.SimpleButton(up, up, up, up);
        btn.x = widthValue - 44;
        btn.y = 28;
        btn.addEventListener(openfl.events.MouseEvent.CLICK, function(_) {
            #if (sys || linux || windows || mac || android)
            try {
                var FileDialog = Type.resolveClass("lime.ui.FileDialog");
                if (FileDialog != null) {
                    var dialog = Type.createInstance(FileDialog, []);
                    dialog.browse(function(path:String) {
                        if (path != null && path != "") field.text = path;
                    }, false);
                } else {
                    field.text = "[No file dialog disponible]";
                }
            } catch(e:Dynamic) {
                field.text = "[No file dialog disponible]";
            }
            #else
            // Fallback web
            var input = new js.html.InputElement();
            input.type = "file";
            input.onchange = function(_) {
                if (input.files.length > 0) {
                    field.text = input.files[0].name;
                }
            };
            input.click();
            #end
        });
        return btn;
    }

    public function setWidth(width:Float):Void {
        widthValue = width;

        labelField.x = 0;
        labelField.y = 0;
        labelField.width = width;
        labelField.height = 20;

        background.graphics.clear();
        background.graphics.beginFill(0x111827);
        background.graphics.drawRoundRect(0, 24, width, 42, 16, 16);
        background.graphics.endFill();

        field.x = 12;
        field.y = 31;
        field.width = width - 60;
        field.height = 24;
        if (browseButton != null) {
            browseButton.x = width - 44;
            browseButton.y = 28;
            if (browseButton.getChildAt(0) != null && Std.isOfType(browseButton.getChildAt(0), openfl.display.Bitmap)) {
                var icon:openfl.display.Bitmap = cast((browseButton.upState, Sprite).getChildAt(0), openfl.display.Bitmap);
                icon.width = 40;
                icon.height = 28;
            }
        }

        hintField.x = 0;
        hintField.y = 71;
        hintField.width = width;
        hintField.height = 18;
    }

    function get_text():String {
        return field.text;
    }

    function set_text(value:String):String {
        field.text = value;
        return value;
    }
}

class UiToggle extends Sprite {
    public var checked(get, set):Bool;

    var box:Shape;
    var labelField:TextField;
    var checkedValue:Bool = false;
    var widthValue:Float = 280;

    public function new(label:String, checked:Bool = false) {
        super();

        buttonMode = true;
        useHandCursor = true;

        box = new Shape();
        addChild(box);

        labelField = new TextField();
        labelField.defaultTextFormat = new TextFormat("_sans", 16, 0xE2E8F0, true);
        labelField.selectable = false;
        labelField.mouseEnabled = false;
        labelField.text = label;
        addChild(labelField);

        checkedValue = checked;

        addEventListener(MouseEvent.CLICK, function(_) {
            this.checked = !this.checked;
            dispatchEvent(new Event(Event.CHANGE));
        });

        setSize(280);
    }

    public function setSize(width:Float):Void {
        widthValue = width;
        draw(widthValue);
    }

    function set_checked(value:Bool):Bool {
        checkedValue = value;
        draw(widthValue);
        return value;
    }

    function get_checked():Bool {
        return checkedValue;
    }

    function draw(width:Float):Void {
        box.graphics.clear();
        box.graphics.beginFill(checkedValue ? 0x22C55E : 0x1E293B);
        box.graphics.drawRoundRect(0, 2, 28, 28, 10, 10);
        box.graphics.endFill();

        if (checkedValue) {
        import openfl.display.Bitmap;
        import openfl.display.Sprite;

            box.graphics.lineStyle(3, 0x04130A);
            box.graphics.moveTo(8, 16);
            box.graphics.lineTo(13, 21);
            box.graphics.lineTo(21, 10);
        }

        labelField.x = 40;
        labelField.y = 4;
        labelField.width = width - 40;
        labelField.height = 26;
    }
}

class AnimationListView extends Sprite {
    public var onSelectionChanged:Void->Void;

    var viewport:Sprite;
    var content:Sprite;
    var viewportMask:Shape;
    var hintField:TextField;

    var items:Array<AnimationChoice> = [];
    var visibleItems:Array<AnimationChoice> = [];
    var viewWidth:Float = 0;
    var viewHeight:Float = 0;
    var rowHeight:Float = 54;
    var scrollOffset:Float = 0;

    var pressing:Bool = false;
    var dragging:Bool = false;
    var pressStageY:Float = 0;
    var scrollAtPress:Float = 0;
    var pressedIndex:Int = -1;

    public function new() {
        super();

        viewport = new Sprite();
        addChild(viewport);

        content = new Sprite();
        viewport.addChild(content);

        viewportMask = new Shape();
        addChild(viewportMask);
        viewport.mask = viewportMask;

        hintField = new TextField();
        hintField.defaultTextFormat = new TextFormat("_sans", 14, 0x64748B);
        hintField.selectable = false;
        hintField.mouseEnabled = false;
        hintField.text = "No hay animaciones cargadas.";
        addChild(hintField);

        viewport.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        viewport.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    public function setSize(width:Float, height:Float):Void {
        viewWidth = width;
        viewHeight = height;

        viewportMask.graphics.clear();
        viewportMask.graphics.beginFill(0xFFFFFF);
        viewportMask.graphics.drawRoundRect(0, 0, width, height, 18, 18);
        viewportMask.graphics.endFill();

        hintField.x = 0;
        hintField.y = 10;
        hintField.width = width;
        hintField.height = 24;

        updateScroll();
    }

    public function setItems(value:Array<AnimationChoice>):Void {
        items = [];
        if (value != null) {
            for (item in value) items.push(item);
        }
        refreshVisible("");
    }

    public function setFilter(value:String):Void {
        refreshVisible(value);
    }

    public function setAllSelected(selected:Bool):Void {
        for (item in items) item.selected = selected;
        rebuildRows();
        notifySelectionChanged();
    }

    public function getSelectedItems():Array<AnimationChoice> {
        var out:Array<AnimationChoice> = [];
        for (item in items) {
            if (item.selected) out.push(item.clone());
        }
        return out;
    }

    function onAddedToStage(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
    }

    function refreshVisible(filterText:String):Void {
        var query = filterText == null ? "" : filterText.toLowerCase();
        visibleItems = [];
        for (item in items) {
            var haystack = (item.name + " " + item.source).toLowerCase();
            if (query == "" || haystack.indexOf(query) != -1) {
                visibleItems.push(item);
            }
        }
        scrollOffset = 0;
        rebuildRows();
    }

    function rebuildRows():Void {
        while (content.numChildren > 0) {
            content.removeChildAt(0);
        }

        var yPos = 0.0;
        for (item in visibleItems) {
            var row = createRow(item, viewWidth, rowHeight);
            row.y = yPos;
            content.addChild(row);
            yPos += rowHeight + 8;
        }

        hintField.visible = visibleItems.length == 0;
        updateScroll();
    }

    function createRow(item:AnimationChoice, width:Float, height:Float):Sprite {
        var row = new Sprite();

        var bg = new Shape();
        bg.graphics.beginFill(item.selected ? 0x172554 : 0x111827);
        bg.graphics.drawRoundRect(0, 0, width - 4, height, 18, 18);
        bg.graphics.endFill();
        row.addChild(bg);

        var check = new Shape();
        check.graphics.beginFill(item.selected ? 0x22C55E : 0x334155);
        check.graphics.drawRoundRect(12, 12, 26, 26, 10, 10);
        check.graphics.endFill();
        if (item.selected) {
            check.graphics.lineStyle(3, 0x04130A);
            check.graphics.moveTo(19, 25);
            check.graphics.lineTo(23, 29);
            check.graphics.lineTo(31, 18);
        }
        row.addChild(check);

        var title = new TextField();
        title.defaultTextFormat = new TextFormat("_sans", 16, 0xF8FAFC, true);
        title.selectable = false;
        title.mouseEnabled = false;
        title.text = item.name;
        title.x = 52;
        title.y = 8;
        title.width = width - 70;
        title.height = 22;
        row.addChild(title);

        var subtitle = new TextField();
        subtitle.defaultTextFormat = new TextFormat("_sans", 12, 0x94A3B8);
        subtitle.selectable = false;
        subtitle.mouseEnabled = false;
        subtitle.text = item.source + buildIndicesLabel(item.indices);
        subtitle.x = 52;
        subtitle.y = 30;
        subtitle.width = width - 70;
        subtitle.height = 18;
        row.addChild(subtitle);

        return row;
    }

    function buildIndicesLabel(indices:Array<Int>):String {
        if (indices == null || indices.length == 0) return "";
        return " | indices: " + indices.join(",");
    }

    function onMouseWheel(event:MouseEvent):Void {
        if (visibleItems.length == 0) return;
        scrollOffset -= event.delta * 18;
        updateScroll();
    }

    function onMouseDown(event:MouseEvent):Void {
        if (visibleItems.length == 0) return;
        pressing = true;
        dragging = false;
        pressStageY = event.stageY;
        scrollAtPress = scrollOffset;
        pressedIndex = rowIndexAt(event.localY + scrollOffset);
    }

    function onStageMouseMove(event:MouseEvent):Void {
        if (!pressing) return;
        var delta = event.stageY - pressStageY;
        if (Math.abs(delta) > 6) dragging = true;
        if (dragging) {
            scrollOffset = scrollAtPress - delta;
            updateScroll();
        }
    }

    function onStageMouseUp(event:MouseEvent):Void {
        if (!pressing) return;
        var local = pointFromStage(event.stageX, event.stageY);
        var releaseIndex = rowIndexAt(local.y + scrollOffset);
        var shouldToggle = !dragging && pressedIndex != -1 && pressedIndex == releaseIndex;
        pressing = false;
        dragging = false;

        if (shouldToggle && pressedIndex >= 0 && pressedIndex < visibleItems.length) {
            visibleItems[pressedIndex].selected = !visibleItems[pressedIndex].selected;
            rebuildRows();
            notifySelectionChanged();
        }
    }

    function pointFromStage(stageX:Float, stageY:Float):{ x:Float, y:Float } {
        var point = this.globalToLocal(new Point(stageX, stageY));
        return { x: point.x, y: point.y };
    }

    function rowIndexAt(positionY:Float):Int {
        if (positionY < 0 || positionY > viewHeight) return -1;
        var step = rowHeight + 8;
        var index = Std.int(positionY / step);
        if (index < 0 || index >= visibleItems.length) return -1;
        var top = index * step;
        return positionY - top <= rowHeight ? index : -1;
    }

    function updateScroll():Void {
        var maxScroll = Math.max(0, content.height - viewHeight);
        if (scrollOffset < 0) scrollOffset = 0;
        if (scrollOffset > maxScroll) scrollOffset = maxScroll;
        content.y = -scrollOffset;
    }

    function notifySelectionChanged():Void {
        if (onSelectionChanged != null) onSelectionChanged();
    }
}
