package;

import openfl.Lib;
import openfl.display.Application;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import Model.LoadResult;
import Model.ProjectPaths;
import UiComponents.AnimationListView;
import UiComponents.CardSection;
import UiComponents.UiButton;
import UiComponents.UiInput;
import UiComponents.UiToggle;

class Main extends Application {
    var booted:Bool = false;

    public function new() {
        super();
    }

    override public function onWindowCreate():Void {
        super.onWindowCreate();

        if (booted) return;
        booted = true;

        Lib.current.addChild(new MainView());
    }
}

class MainView extends Sprite {
        #if (linux || windows || mac)
        var zoomLevel:Float = 1.0;
        #end
    var backgroundLayer:Shape;
    var accentLayer:Shape;

    var titleField:TextField;
    var subtitleField:TextField;
    var statusBadge:Shape;
    var statusField:TextField;

    var inputsCard:CardSection;
    var animationsCard:CardSection;
    var previewCard:CardSection;
    var logCard:CardSection;

    var animationJsonInput:UiInput;
    var atlasJsonInput:UiInput;
    var atlasPngInput:UiInput;
    var animsXmlInput:UiInput;
    var animsJsonInput:UiInput;
    var outputDirInput:UiInput;
    var filterInput:UiInput;

    var exportFramesToggle:UiToggle;

    var sampleButton:UiButton;
    var refreshButton:UiButton;
    var previewButton:UiButton;
    var exportButton:UiButton;
    var allButton:UiButton;
    var noneButton:UiButton;

    var animationsView:AnimationListView;
    var selectionField:TextField;
    var helperField:TextField;

    var previewFrame:Shape;
    var previewBitmap:Bitmap;
    var previewHintField:TextField;
    var previewPathField:TextField;
    var currentPreview:BitmapData;

    var logField:TextField;
    var logLines:Array<String> = [];

    var paths:ProjectPaths;
    var statusColor:Int = 0x334155;

    public function new() {
        super();

        if (stage != null) init();
        else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        #if (linux || windows || mac)
        addEventListener(Event.ADDED_TO_STAGE, function(_) {
            if (stage != null) {
                stage.addEventListener(openfl.events.MouseEvent.MOUSE_WHEEL, onMouseWheelZoom);
            }
        });
        #end
    }
    #if (linux || windows || mac)
    function onMouseWheelZoom(e:openfl.events.MouseEvent):Void {
        if (openfl.Lib.current.window != null && openfl.Lib.current.window.displayState == "normal" && e.ctrlKey) {
            var oldZoom = zoomLevel;
            zoomLevel += e.delta > 0 ? 0.1 : -0.1;
            if (zoomLevel < 0.3) zoomLevel = 0.3;
            if (zoomLevel > 2.5) zoomLevel = 2.5;
            if (zoomLevel != oldZoom) {
                this.scaleX = zoomLevel;
                this.scaleY = zoomLevel;
            }
        }
    }
    #end

    function onAddedToStage(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        init();
    }

    function init():Void {
        stage.scaleMode = StageScaleMode.NO_SCALE;
        stage.align = StageAlign.TOP_LEFT;
        stage.color = 0x050816;

        paths = new ProjectPaths();

        buildChrome();
        buildInputs();
        buildAnimations();
        buildPreview();
        buildLog();

        stage.addEventListener(Event.RESIZE, onResize);
        layout();

        var sample = Backend.discoverSamplePaths();
        if (sample != null) {
            applyPaths(sample);
            appendLog("Sample local detectado. Dejé las rutas listas para probar.");
            refreshProject();
        } else {
            outputDirInput.text = "out/mobile";
            appendLog("Pega rutas reales o usa archivos del proyecto y toca Refrescar.");
            setStatus("Esperando rutas", 0x475569);
        }
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
        titleField.text = "Spritemap to Funky";
        addChild(titleField);
        /*
        #if (linux || windows || mac)
        // Permitir renombrar la ventana desde el código
        try {
            openfl.Lib.current.stage.window.title = "Spritemap to Funky";
        } catch(e:Dynamic) {}
        #end */
        subtitleField = new TextField();
        subtitleField.defaultTextFormat = new TextFormat("_sans", 15, 0x94A3B8);
        subtitleField.selectable = false;
        subtitleField.mouseEnabled = false;
        subtitleField.multiline = true;
        subtitleField.wordWrap = true;
        #if android
        subtitleField.text = "La mejor app!";
        #elseif linux
        subtitleField.text = "Test on linux or... what?";
        #else
        subtitleField.text = "La mejor app! - Test on linux or... what? - Plataforma desconocida.";
        #end
        addChild(subtitleField);

        statusBadge = new Shape();
        addChild(statusBadge);

        statusField = new TextField();
        statusField.defaultTextFormat = new TextFormat("_sans", 13, 0xE2E8F0, true);
        statusField.selectable = false;
        statusField.mouseEnabled = false;
        statusField.autoSize = TextFieldAutoSize.LEFT;
        addChild(statusField);

        inputsCard = new CardSection("Entradas y acciones");
        addChild(inputsCard);

        animationsCard = new CardSection("Animaciones");
        addChild(animationsCard);

        previewCard = new CardSection("Preview");
        addChild(previewCard);

        logCard = new CardSection("Log");
        addChild(logCard);
    }

    function buildInputs():Void {
        animationJsonInput = new UiInput("Animation.json", "Ruta del timeline principal exportado desde Animate.");
        atlasJsonInput = new UiInput("spritemap1.json", "Ruta del atlas con nombres, bounds y meta.image.");
        atlasPngInput = new UiInput("Atlas PNG (opcional)", "Si lo dejas vacío, se resuelve desde spritemap1.json.");
        animsXmlInput = new UiInput("anims.xml (opcional)", "Lista estilo Codename con name/anim/indices.");
        animsJsonInput = new UiInput("anims.json (opcional)", "Lista estilo Psych/FNF con animations[].");
        outputDirInput = new UiInput("Salida", "Carpeta donde se escriben los PNG exportados.");
        filterInput = new UiInput("Filtro", "Filtra la lista por nombre o símbolo.");

        // Forzar ruta de salida fija android
        #if (android)
        var forcedOutput = "~/storage/shared/Pictures/SpritemapToFunky/";
        outputDirInput.text = forcedOutput;
        outputDirInput.field.addEventListener(Event.CHANGE, function(_) {
            if (outputDirInput.text != forcedOutput) {
                outputDirInput.text = forcedOutput;
            }
        });
        #end
        // Forzar ruta de salida fija linux
        #if (linux)
        var forcedOutput = Path.join('${Dirname}/out/');
        outputDirInput.text = forcedOutput;
        outputDirInput.field.addEventListener(Event.CHANGE, function(_) {
            if (outputDirInput.text != forcedOutput) {
                outputDirInput.text = forcedOutput;
            }
        });
        #end

        exportFramesToggle = new UiToggle("Exportar frames PNG", true);

        sampleButton = new UiButton("Cargar sample", 0x0F766E);
        refreshButton = new UiButton("Refrescar anims", 0x2563EB);
        previewButton = new UiButton("Cargar preview", 0x7C3AED);
        exportButton = new UiButton("Exportar", 0xEA580C);
        allButton = new UiButton("Todo", 0x1D4ED8);
        noneButton = new UiButton("Nada", 0x334155);

        inputsCard.content.addChild(animationJsonInput);
        inputsCard.content.addChild(atlasJsonInput);
        inputsCard.content.addChild(atlasPngInput);
        inputsCard.content.addChild(animsXmlInput);
        inputsCard.content.addChild(animsJsonInput);
        inputsCard.content.addChild(outputDirInput);
        inputsCard.content.addChild(exportFramesToggle);
        inputsCard.content.addChild(sampleButton);
        inputsCard.content.addChild(refreshButton);
        inputsCard.content.addChild(previewButton);
        inputsCard.content.addChild(exportButton);

        sampleButton.addEventListener(MouseEvent.CLICK, function(_) {
            var sample = Backend.discoverSamplePaths();
            if (sample == null) {
                appendLog("No encontré sample local en este build.");
                setStatus("Sin sample", 0x7C2D12);
                return;
            }
            applyPaths(sample);
            appendLog("Rutas del sample cargadas.");
            refreshProject();
        });

        refreshButton.addEventListener(MouseEvent.CLICK, function(_) {
            refreshProject();
        });

        previewButton.addEventListener(MouseEvent.CLICK, function(_) {
            loadPreview();
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
        helperField.text = "En móvil puedes tocar una fila para activarla o desactivarla. Si deslizas verticalmente, la lista hace scroll.";
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

    function buildPreview():Void {
        previewFrame = new Shape();
        previewCard.content.addChild(previewFrame);

        previewBitmap = new Bitmap();
        previewCard.content.addChild(previewBitmap);

        previewHintField = new TextField();
        previewHintField.defaultTextFormat = new TextFormat("_sans", 15, 0x94A3B8, true);
        previewHintField.selectable = false;
        previewHintField.mouseEnabled = false;
        previewHintField.multiline = true;
        previewHintField.wordWrap = true;
        previewHintField.text = "Sin preview todavía. Carga rutas válidas y toca Cargar preview.";
        previewCard.content.addChild(previewHintField);

        previewPathField = new TextField();
        previewPathField.defaultTextFormat = new TextFormat("_sans", 12, 0x64748B);
        previewPathField.selectable = false;
        previewPathField.mouseEnabled = false;
        previewPathField.multiline = true;
        previewPathField.wordWrap = true;
        previewCard.content.addChild(previewPathField);
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

    function applyPaths(newPaths:ProjectPaths):Void {
        paths = newPaths.clone();
        animationJsonInput.text = paths.animationJson;
        atlasJsonInput.text = paths.atlasJson;
        atlasPngInput.text = paths.atlasPng;
        animsXmlInput.text = paths.animsXml;
        animsJsonInput.text = paths.animsJson;
        outputDirInput.text = paths.outputDir;
    }

    function syncPathsFromInputs():Void {
        paths.animationJson = animationJsonInput.text;
        paths.atlasJson = atlasJsonInput.text;
        paths.atlasPng = atlasPngInput.text;
        paths.animsXml = animsXmlInput.text;
        paths.animsJson = animsJsonInput.text;
        // Siempre forzar la ruta de salida
        paths.outputDir = "~/storage/shared/Pictures/SpritemapToFunky/";
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

            if (result.previewPath != null && result.previewPath != "") {
                previewPathField.text = result.previewPath;
            } else {
                previewPathField.text = "";
            }

            setStatus("Animaciones listas", result.animations.length > 0 ? 0x0F766E : 0x475569);
        } catch (error:Dynamic) {
            appendLog("Refresh falló: " + Std.string(error));
            setStatus("Error leyendo rutas", 0x7C2D12);
        }
    }

    function loadPreview():Void {
        syncPathsFromInputs();
        setStatus("Cargando preview...", 0x4338CA);
        try {
            var previewPath = Backend.resolvePreviewPath(paths);
            if (previewPath == null || previewPath == "") {
                previewHintField.text = "No pude resolver la ruta del atlas PNG.";
                previewBitmap.bitmapData = null;
                setStatus("Preview vacía", 0x7C2D12);
                return;
            }

            var bitmapData = Backend.loadPreviewBitmap(previewPath);
            if (bitmapData == null) {
                previewHintField.text = "El atlas existe pero OpenFL no logró abrirlo.";
                previewBitmap.bitmapData = null;
                setStatus("Preview falló", 0x7C2D12);
                return;
            }

            if (currentPreview != null) currentPreview.dispose();
            currentPreview = bitmapData;
            previewBitmap.bitmapData = currentPreview;
            previewPathField.text = previewPath;
            previewHintField.text = "";
            fitPreviewBitmap();
            appendLog("Preview cargada desde: " + previewPath);
            setStatus("Preview lista", 0x0F766E);
        } catch (error:Dynamic) {
            appendLog("Preview falló: " + Std.string(error));
            previewHintField.text = "No pude cargar la imagen del atlas.";
            previewBitmap.bitmapData = null;
            setStatus("Preview falló", 0x7C2D12);
        }
    }

    function runExport():Void {
        syncPathsFromInputs();
        setStatus("Exportando...", 0xC2410C);
        exportButton.enabled = false;

        try {
            var result = Backend.exportProject(paths, animationsView.getSelectedItems(), exportFramesToggle.checked);
            if (result.log != "") appendLog(result.log);
            if (result.filesWritten > 0) {
                outputDirInput.text = result.outputDir;
                setStatus("Export completo", 0x15803D);
            } else {
                setStatus("Nada exportado", 0x7C2D12);
            }
        } catch (error:Dynamic) {
            appendLog("Export falló: " + Std.string(error));
            setStatus("Export falló", 0x7C2D12);
        }

        exportButton.enabled = true;
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
        statusBadge.graphics.drawRoundRect(
            stage.stageWidth - statusField.textWidth - 70,
            28,
            statusField.textWidth + 34,
            28,
            14,
            14
        );
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

            var inputsHeight = Math.min(688.0, height - contentTop - margin - 200);
            if (inputsHeight < 520) inputsHeight = 520;
            var previewHeight = Math.max(280.0, height * 0.44);

            inputsCard.x = margin;
            inputsCard.y = contentTop;
            inputsCard.setSize(leftWidth, inputsHeight);

            animationsCard.x = margin;
            animationsCard.y = inputsCard.y + inputsHeight + gap;
            animationsCard.setSize(leftWidth, Math.max(220.0, height - animationsCard.y - margin));

            previewCard.x = margin + leftWidth + gap;
            previewCard.y = contentTop;
            previewCard.setSize(rightWidth, previewHeight);

            logCard.x = previewCard.x;
            logCard.y = previewCard.y + previewHeight + gap;
            logCard.setSize(rightWidth, Math.max(220.0, height - logCard.y - margin));
        } else {
            var fullWidth = width - margin * 2;
            var nextY = contentTop;
            var inputsHeight = 700.0;
            var animationsHeight = 330.0;
            var previewHeight = 320.0;

            inputsCard.x = margin;
            inputsCard.y = nextY;
            inputsCard.setSize(fullWidth, inputsHeight);
            nextY += inputsHeight + gap;

            animationsCard.x = margin;
            animationsCard.y = nextY;
            animationsCard.setSize(fullWidth, animationsHeight);
            nextY += animationsHeight + gap;

            previewCard.x = margin;
            previewCard.y = nextY;
            previewCard.setSize(fullWidth, previewHeight);
            nextY += previewHeight + gap;

            logCard.x = margin;
            logCard.y = nextY;
            logCard.setSize(fullWidth, Math.max(220.0, height - nextY - margin));
        }

        layoutInputsCard();
        layoutAnimationsCard();
        layoutPreviewCard();
        layoutLogCard();
        fitPreviewBitmap();
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
        y += rowGap;

        outputDirInput.x = 0;
        outputDirInput.y = y;
        outputDirInput.setWidth(cardWidth);
        y += rowGap + 2;

        exportFramesToggle.x = 0;
        exportFramesToggle.y = y;
        exportFramesToggle.setSize(cardWidth);
        y += 44;

        var halfWidth = (cardWidth - 10) * 0.5;
        sampleButton.x = 0;
        sampleButton.y = y;
        sampleButton.setSize(halfWidth, 52);

        refreshButton.x = halfWidth + 10;
        refreshButton.y = y;
        refreshButton.setSize(halfWidth, 52);
        y += 62;

        previewButton.x = 0;
        previewButton.y = y;
        previewButton.setSize(halfWidth, 52);

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

    function layoutPreviewCard():Void {
        var innerWidth = previewCard.innerWidth;
        var innerHeight = previewCard.innerHeight;
        var previewHeight = Math.max(120, innerHeight - 72);

        previewFrame.graphics.clear();
        previewFrame.graphics.beginFill(0x111827);
        previewFrame.graphics.drawRoundRect(0, 0, innerWidth, previewHeight, 24, 24);
        previewFrame.graphics.endFill();

        previewHintField.x = 22;
        previewHintField.y = 18;
        previewHintField.width = innerWidth - 44;
        previewHintField.height = 56;

        previewPathField.x = 0;
        previewPathField.y = previewHeight + 12;
        previewPathField.width = innerWidth;
        previewPathField.height = 54;
    }

    function layoutLogCard():Void {
        logField.x = 0;
        logField.y = 0;
        logField.width = logCard.innerWidth;
        logField.height = logCard.innerHeight;
    }

    function fitPreviewBitmap():Void {
        if (previewBitmap.bitmapData == null) {
            previewBitmap.visible = false;
            previewHintField.visible = true;
            return;
        }

        var areaWidth = previewCard.innerWidth - 24;
        var areaHeight = Math.max(120, previewCard.innerHeight - 96) - 24;
        var scale = Math.min(areaWidth / previewBitmap.bitmapData.width, areaHeight / previewBitmap.bitmapData.height);
        if (scale > 1) scale = 1;

        previewBitmap.scaleX = scale;
        previewBitmap.scaleY = scale;
        previewBitmap.x = (previewCard.innerWidth - previewBitmap.bitmapData.width * scale) * 0.5;
        previewBitmap.y = (Math.max(120, previewCard.innerHeight - 72) - previewBitmap.bitmapData.height * scale) * 0.5;
        previewBitmap.visible = true;
        previewHintField.visible = false;
    }

    function drawBackground(width:Float, height:Float):Void {
        backgroundLayer.graphics.clear();
        backgroundLayer.graphics.beginFill(0x050816);
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
