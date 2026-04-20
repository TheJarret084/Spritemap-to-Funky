package android;

import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;
import android.UiComponents.AnimationListView;
import android.UiComponents.CardSection;
import android.UiComponents.UiBrowseMode;
import android.UiComponents.UiButton;
import android.UiComponents.UiInput;
import android.UiComponents.UiToggle;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class MainView extends Sprite {
    var backgroundLayer:Shape;
    var accentLayer:Shape;

    var titleField:TextField;
    var subtitleField:TextField;
    var statusBadge:Shape;
    var statusField:TextField;

    var inputsCard:CardSection;
    var animationsCard:CardSection;
    var logCard:CardSection;

    var animationJsonInput:UiInput;
    var atlasJsonInput:UiInput;
    var atlasPngInput:UiInput;
    var animsXmlInput:UiInput;
    var animsJsonInput:UiInput;
    var filterInput:UiInput;

    var exportFramesToggle:UiToggle;
    var refreshButton:UiButton;
    var exportButton:UiButton;
    var allButton:UiButton;
    var noneButton:UiButton;

    var animationsView:AnimationListView;
    var selectionField:TextField;
    var helperField:TextField;

    var logField:TextField;
    var logLines:Array<String> = [];

    var paths:ProjectPaths;
    var statusColor:Int = 0x334155;

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
        stage.scaleMode = StageScaleMode.NO_SCALE;
        stage.align = StageAlign.TOP_LEFT;
        stage.color = AppConfig.BACKGROUND_COLOR;

        paths = Backend.createDefaultPaths();

        buildChrome();
        buildInputs();
        buildAnimations();
        buildLog();

        stage.addEventListener(Event.RESIZE, onResize);
        layout();

        appendLog("Selecciona los archivos del proyecto.");
        appendLog("La app los copia al storage interno de Android y al final guarda un ZIP.");
        setStatus("Esperando archivos", 0x475569);
    }

    function buildChrome():Void {
        backgroundLayer = new Shape();
        addChild(backgroundLayer);

        accentLayer = new Shape();
        addChild(accentLayer);

        titleField = new TextField();
        titleField.defaultTextFormat = new TextFormat("_sans", 34, 0xF8FAFC, true);
        titleField.selectable = false;
        titleField.mouseEnabled = false;
        titleField.text = AppConfig.APP_TITLE;
        addChild(titleField);

        subtitleField = new TextField();
        subtitleField.defaultTextFormat = new TextFormat("_sans", 15, 0x94A3B8);
        subtitleField.selectable = false;
        subtitleField.mouseEnabled = false;
        subtitleField.multiline = true;
        subtitleField.wordWrap = true;
        subtitleField.text = AppConfig.APP_SUBTITLE;
        addChild(subtitleField);

        statusBadge = new Shape();
        addChild(statusBadge);

        statusField = new TextField();
        statusField.defaultTextFormat = new TextFormat("_sans", 13, 0xE2E8F0, true);
        statusField.selectable = false;
        statusField.mouseEnabled = false;
        statusField.autoSize = TextFieldAutoSize.LEFT;
        addChild(statusField);

        inputsCard = new CardSection("Archivos");
        addChild(inputsCard);

        animationsCard = new CardSection("Animaciones");
        addChild(animationsCard);

        logCard = new CardSection("Log");
        addChild(logCard);
    }

    function buildInputs():Void {
        animationJsonInput = new UiInput("Animation.json", "Selecciona el timeline principal.", OPEN_FILE, "json", "Selecciona Animation.json");
        atlasJsonInput = new UiInput("spritemap1.json", "Selecciona el atlas JSON.", OPEN_FILE, "json", "Selecciona spritemap1.json");
        atlasPngInput = new UiInput("Atlas PNG (opcional)", "Si lo dejas vacío, se resuelve desde spritemap1.json.", OPEN_FILE, "png", "Selecciona atlas PNG");
        animsXmlInput = new UiInput("anims.xml (opcional)", "Lista estilo Codename.", OPEN_FILE, "xml", "Selecciona anims.xml");
        animsJsonInput = new UiInput("anims.json (opcional)", "Lista estilo Psych/FNF.", OPEN_FILE, "json", "Selecciona anims.json");
        filterInput = new UiInput("Filtro", "Filtra por nombre o símbolo.", NONE);

        exportFramesToggle = new UiToggle("Exportar frames PNG", true);

        refreshButton = new UiButton("Refrescar anims", 0x2563EB);
        exportButton = new UiButton("Guardar ZIP", 0xEA580C);
        allButton = new UiButton("Todo", 0x1D4ED8);
        noneButton = new UiButton("Nada", 0x334155);

        inputsCard.content.addChild(animationJsonInput);
        inputsCard.content.addChild(atlasJsonInput);
        inputsCard.content.addChild(atlasPngInput);
        inputsCard.content.addChild(animsXmlInput);
        inputsCard.content.addChild(animsJsonInput);
        inputsCard.content.addChild(exportFramesToggle);
        inputsCard.content.addChild(refreshButton);
        inputsCard.content.addChild(exportButton);

        refreshButton.addEventListener(MouseEvent.CLICK, function(_) {
            refreshProject();
        });

        exportButton.addEventListener(MouseEvent.CLICK, function(_) {
            runExport();
        });

        filterInput.field.addEventListener(Event.CHANGE, function(_) {
            animationsView.setFilter(filterInput.text);
            updateSelectionSummary();
        });
    }

    function buildAnimations():Void {
        selectionField = new TextField();
        selectionField.defaultTextFormat = new TextFormat("_sans", 13, 0x93C5FD, true);
        selectionField.selectable = false;
        selectionField.mouseEnabled = false;
        selectionField.text = "0 seleccionadas";
        animationsCard.content.addChild(selectionField);

        helperField = new TextField();
        helperField.defaultTextFormat = new TextFormat("_sans", 12, 0x64748B);
        helperField.selectable = false;
        helperField.mouseEnabled = false;
        helperField.multiline = true;
        helperField.wordWrap = true;
        helperField.text = "Toca una fila para activarla o desactivarla. Si deslizas verticalmente, la lista hace scroll.";
        animationsCard.content.addChild(helperField);

        animationsView = new AnimationListView();
        animationsView.onSelectionChanged = function() {
            updateSelectionSummary();
        };
        animationsCard.content.addChild(animationsView);

        animationsCard.content.addChild(filterInput);
        animationsCard.content.addChild(allButton);
        animationsCard.content.addChild(noneButton);

        allButton.addEventListener(MouseEvent.CLICK, function(_) {
            animationsView.setAllSelected(true);
        });

        noneButton.addEventListener(MouseEvent.CLICK, function(_) {
            animationsView.setAllSelected(false);
        });
    }

    function buildLog():Void {
        logField = new TextField();
        logField.defaultTextFormat = new TextFormat("_typewriter", 13, 0xE2E8F0);
        logField.selectable = true;
        logField.multiline = true;
        logField.wordWrap = true;
        logField.mouseWheelEnabled = true;
        logCard.content.addChild(logField);
    }

    function syncPathsFromInputs():Void {
        paths.animationJson = animationJsonInput.text;
        paths.atlasJson = atlasJsonInput.text;
        paths.atlasPng = atlasPngInput.text;
        paths.animsXml = animsXmlInput.text;
        paths.animsJson = animsJsonInput.text;
        paths.outputDir = Backend.getProcessingOutputDir();
    }

    function refreshProject():Void {
        syncPathsFromInputs();
        setStatus("Leyendo proyecto...", 0x1D4ED8);

        try {
            var result:LoadResult = Backend.loadProject(paths);
            animationsView.setItems(result.animations);
            animationsView.setFilter(filterInput.text);
            updateSelectionSummary();
            appendLog(result.log);
            setStatus("Animaciones listas", result.animations.length > 0 ? 0x0F766E : 0x475569);
        } catch (error:Dynamic) {
            appendLog("Refresh falló: " + Std.string(error));
            setStatus("Error leyendo rutas", 0x7C2D12);
        }
    }

    function runExport():Void {
        syncPathsFromInputs();
        setStatus("Procesando export...", 0xC2410C);
        exportButton.enabled = false;

        try {
            var result = Backend.exportProject(paths, animationsView.getSelectedItems(), exportFramesToggle.checked);
            if (result.log != "") appendLog(result.log);

            if (result.filesWritten <= 0 || result.archivePath == "") {
                setStatus("Nada exportado", 0x7C2D12);
                exportButton.enabled = true;
                return;
            }

            setStatus("Elige dónde guardar el ZIP", 0x2563EB);
            var opened = AndroidFilePicker.saveFile(
                AppConfig.SAVE_DIALOG_TITLE,
                result.archiveName,
                result.archivePath,
                function(savedPath:String) {
                    appendLog("ZIP guardado: " + savedPath);
                    Backend.cleanupAfterSave();
                    resetAfterSuccessfulSave();
                    setStatus("ZIP guardado", 0x15803D);
                    exportButton.enabled = true;
                },
                function(message:String) {
                    appendLog("No pude guardar el ZIP: " + message);
                    setStatus("ZIP listo para reintentar", 0x7C2D12);
                    exportButton.enabled = true;
                }
            );

            if (!opened) {
                appendLog("No pude abrir el selector para guardar.");
                setStatus("Error al guardar", 0x7C2D12);
                exportButton.enabled = true;
            }
        } catch (error:Dynamic) {
            appendLog("Export falló: " + Std.string(error));
            setStatus("Export falló", 0x7C2D12);
            exportButton.enabled = true;
        }
    }

    function resetAfterSuccessfulSave():Void {
        paths = Backend.createDefaultPaths();
        animationJsonInput.text = "";
        atlasJsonInput.text = "";
        atlasPngInput.text = "";
        animsXmlInput.text = "";
        animsJsonInput.text = "";
        filterInput.text = "";
        animationsView.setItems([]);
        updateSelectionSummary();
        appendLog("Workspace temporal limpiado.");
    }

    function appendLog(line:String):Void {
        if (line == null || StringTools.trim(line) == "") return;
        for (piece in line.split("\n")) {
            var clean = StringTools.trim(piece);
            if (clean == "") continue;
            logLines.push(clean);
        }
        while (logLines.length > 220) logLines.shift();
        logField.text = logLines.join("\n");
        logField.scrollV = logField.maxScrollV;
    }

    function updateSelectionSummary():Void {
        var selected = animationsView.getSelectedItems().length;
        selectionField.text = selected + " seleccionadas";
    }

    function setStatus(text:String, color:Int):Void {
        statusColor = color;
        statusField.text = text;
        statusField.x = stage.stageWidth - statusField.textWidth - 54;
        statusField.y = 34;

        statusBadge.graphics.clear();
        statusBadge.graphics.beginFill(statusColor, 0.95);
        statusBadge.graphics.drawRoundRect(stage.stageWidth - statusField.textWidth - 70, 28, statusField.textWidth + 34, 28, 14, 14);
        statusBadge.graphics.endFill();
    }

    function onResize(_:Event):Void {
        layout();
    }

    function layout():Void {
        var width = stage.stageWidth;
        var height = stage.stageHeight;
        var margin = width < 900 ? 18.0 : 24.0;
        var headerHeight = 116.0;

        drawBackground(width, height);

        titleField.x = margin;
        titleField.y = 24;
        titleField.width = width - margin * 2 - 180;
        titleField.height = 40;

        subtitleField.x = margin;
        subtitleField.y = 70;
        subtitleField.width = width - margin * 2 - 180;
        subtitleField.height = 42;

        var contentTop = headerHeight + margin;
        var gap = 18.0;

        if (width >= 980) {
            var leftWidth = Math.max(360.0, width * 0.42);
            var rightWidth = width - margin * 2 - leftWidth - gap;

            var inputsHeight = Math.min(620.0, height - contentTop - margin - 200);
            if (inputsHeight < 460) inputsHeight = 460;
            var logHeight = Math.max(300.0, height - contentTop - margin);

            inputsCard.x = margin;
            inputsCard.y = contentTop;
            inputsCard.setSize(leftWidth, inputsHeight);

            animationsCard.x = margin;
            animationsCard.y = inputsCard.y + inputsHeight + gap;
            animationsCard.setSize(leftWidth, Math.max(220.0, height - animationsCard.y - margin));

            logCard.x = margin + leftWidth + gap;
            logCard.y = contentTop;
            logCard.setSize(rightWidth, logHeight);
        } else {
            var fullWidth = width - margin * 2;
            var nextY = contentTop;
            var inputsHeight = 620.0;
            var animationsHeight = 330.0;

            inputsCard.x = margin;
            inputsCard.y = nextY;
            inputsCard.setSize(fullWidth, inputsHeight);
            nextY += inputsHeight + gap;

            animationsCard.x = margin;
            animationsCard.y = nextY;
            animationsCard.setSize(fullWidth, animationsHeight);
            nextY += animationsHeight + gap;

            logCard.x = margin;
            logCard.y = nextY;
            logCard.setSize(fullWidth, Math.max(220.0, height - nextY - margin));
        }

        layoutInputsCard();
        layoutAnimationsCard();
        layoutLogCard();
        setStatus(statusField.text == null || statusField.text == "" ? "Listo" : statusField.text, statusColor);
    }

    function layoutInputsCard():Void {
        var cardWidth = inputsCard.innerWidth;
        var y = 0.0;
        var rowGap = 88.0;

        animationJsonInput.x = 0;
        animationJsonInput.y = y;
        animationJsonInput.setWidth(cardWidth);
        y += rowGap;

        atlasJsonInput.x = 0;
        atlasJsonInput.y = y;
        atlasJsonInput.setWidth(cardWidth);
        y += rowGap;

        atlasPngInput.x = 0;
        atlasPngInput.y = y;
        atlasPngInput.setWidth(cardWidth);
        y += rowGap;

        animsXmlInput.x = 0;
        animsXmlInput.y = y;
        animsXmlInput.setWidth(cardWidth);
        y += rowGap;

        animsJsonInput.x = 0;
        animsJsonInput.y = y;
        animsJsonInput.setWidth(cardWidth);
        y += rowGap + 2;

        exportFramesToggle.x = 0;
        exportFramesToggle.y = y;
        exportFramesToggle.setSize(cardWidth);
        y += 44;

        var halfWidth = (cardWidth - 10) * 0.5;
        refreshButton.x = 0;
        refreshButton.y = y;
        refreshButton.setSize(halfWidth, 52);

        exportButton.x = halfWidth + 10;
        exportButton.y = y;
        exportButton.setSize(halfWidth, 52);
    }

    function layoutAnimationsCard():Void {
        selectionField.x = 0;
        selectionField.y = 0;
        selectionField.width = animationsCard.innerWidth;
        selectionField.height = 20;

        filterInput.x = 0;
        filterInput.y = 26;
        filterInput.setWidth(animationsCard.innerWidth);

        var actionsY = 116.0;
        var buttonWidth = (animationsCard.innerWidth - 10) * 0.5;
        allButton.x = 0;
        allButton.y = actionsY;
        allButton.setSize(buttonWidth, 46);

        noneButton.x = buttonWidth + 10;
        noneButton.y = actionsY;
        noneButton.setSize(buttonWidth, 46);

        helperField.x = 0;
        helperField.y = 170;
        helperField.width = animationsCard.innerWidth;
        helperField.height = 36;

        animationsView.x = 0;
        animationsView.y = 214;
        animationsView.setSize(animationsCard.innerWidth, Math.max(60, animationsCard.innerHeight - 214));
    }

    function layoutLogCard():Void {
        logField.x = 0;
        logField.y = 0;
        logField.width = logCard.innerWidth;
        logField.height = logCard.innerHeight;
    }

    function drawBackground(width:Float, height:Float):Void {
        backgroundLayer.graphics.clear();
        backgroundLayer.graphics.beginFill(AppConfig.BACKGROUND_COLOR);
        backgroundLayer.graphics.drawRect(0, 0, width, height);
        backgroundLayer.graphics.endFill();

        accentLayer.graphics.clear();
        accentLayer.graphics.beginFill(0x0EA5E9, 0.14);
        accentLayer.graphics.drawCircle(width * 0.16, height * 0.12, width * 0.22);
        accentLayer.graphics.endFill();
        accentLayer.graphics.beginFill(0xFB7185, 0.10);
        accentLayer.graphics.drawCircle(width * 0.88, height * 0.18, width * 0.18);
        accentLayer.graphics.endFill();
        accentLayer.graphics.beginFill(0x22C55E, 0.10);
        accentLayer.graphics.drawCircle(width * 0.72, height * 0.88, width * 0.20);
        accentLayer.graphics.endFill();
    }
}
