package android;

import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;
import android.AppConfig.ProjectInfoEntryData;
import android.UiComponents.AnimationListView;
import android.UiComponents.CardSection;
import android.UiComponents.UiBrowseMode;
import android.UiComponents.UiButton;
import android.UiComponents.UiInput;
import android.UiComponents.UiToggle;
import android.AppConfig.ProjectInfoData;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.net.URLRequest;
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

    var infoButton:Sprite;
    var infoButtonBg:Shape;
    var infoButtonIcon:Bitmap;

    var aboutOverlay:Sprite;
    var aboutScrim:Shape;
    var aboutCard:CardSection;
    var aboutIntroField:TextField;
    var aboutProjectField:TextField;
    var aboutTeamList:Sprite;
    var aboutExtraField:TextField;
    var aboutLinkButton:UiButton;
    var aboutCloseButton:UiButton;
    var aboutVisible:Bool = false;

    var paths:ProjectPaths;
    var projectInfo:ProjectInfoData;
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
        projectInfo = AppConfig.getProjectInfo();

        buildChrome();
        buildInputs();
        buildAnimations();
        buildLog();
        buildAboutOverlay();

        stage.addEventListener(Event.RESIZE, onResize);
        layout();

        appendLog("Selecciona los archivos del proyecto.");
        appendLog("La app los copia al storage interno de Android y al final guarda un ZIP.");
        appendLog("La build movil exporta directo a ZIP; el flujo de Aseprite ya no aplica aqui.");
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

        buildInfoButton();
    }

    function buildInputs():Void {
        animationJsonInput = new UiInput("Animation.json", "Selecciona el timeline principal.", OPEN_FILE, "json", "Selecciona Animation.json");
        atlasJsonInput = new UiInput("spritemap1.json", "Selecciona el atlas JSON.", OPEN_FILE, "json", "Selecciona spritemap1.json");
        atlasPngInput = new UiInput("Atlas PNG", "Si lo dejas vacío, se resuelve desde spritemap1.json.", OPEN_FILE, "png", "Selecciona atlas PNG");
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
        helperField.text = "Toca una fila para activarla o desactivarla. Desliza verticalmente para hacer scroll y exportar solo lo que te interesa.";
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

    function buildInfoButton():Void {
        infoButton = new Sprite();
        infoButton.buttonMode = true;
        infoButton.useHandCursor = true;
        infoButton.mouseChildren = false;

        infoButtonBg = new Shape();
        infoButton.addChild(infoButtonBg);

        infoButtonIcon = new Bitmap(openfl.Assets.getBitmapData(AppConfig.resolveAssetPath(AppConfig.ABOUT_ICON_ASSET)));
        infoButtonIcon.smoothing = true;
        infoButton.addChild(infoButtonIcon);

        infoButton.addEventListener(MouseEvent.CLICK, function(_) {
            toggleAbout();
        });

        addChild(infoButton);
    }

    function buildAboutOverlay():Void {
        aboutOverlay = new Sprite();
        aboutOverlay.visible = false;
        addChild(aboutOverlay);

        aboutScrim = new Shape();
        aboutOverlay.addChild(aboutScrim);
        aboutScrim.addEventListener(MouseEvent.CLICK, function(_) {
            toggleAbout(false);
        });

        aboutCard = new CardSection(projectInfo.panelTitle);
        aboutOverlay.addChild(aboutCard);

        aboutIntroField = createAboutField(16, 0xE2E8F0, false);
        aboutProjectField = createAboutField(13, 0x93C5FD, false);
        aboutProjectField.selectable = true;
        aboutProjectField.mouseEnabled = true;
        aboutTeamList = new Sprite();
        aboutExtraField = createAboutField(12, 0x94A3B8, false);

        aboutLinkButton = new UiButton(projectInfo.linkLabel, 0x0EA5E9);
        aboutCloseButton = new UiButton("Cerrar", 0x334155);

        aboutCard.content.addChild(aboutIntroField);
        aboutCard.content.addChild(aboutProjectField);
        aboutCard.content.addChild(aboutTeamList);
        aboutCard.content.addChild(aboutExtraField);
        aboutCard.content.addChild(aboutLinkButton);
        aboutCard.content.addChild(aboutCloseButton);

        aboutLinkButton.addEventListener(MouseEvent.CLICK, function(_) {
            openProjectLink();
        });

        aboutCloseButton.addEventListener(MouseEvent.CLICK, function(_) {
            toggleAbout(false);
        });

        refreshAboutText();
    }

    function createAboutField(size:Int, color:Int, bold:Bool):TextField {
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", size, color, bold);
        field.textColor = color;
        field.selectable = false;
        field.mouseEnabled = false;
        field.multiline = true;
        field.wordWrap = true;
        return field;
    }

    function refreshAboutText():Void {
        aboutIntroField.text = projectInfo.projectName + "\n" + projectInfo.overviewLines.join("\n");
        aboutProjectField.text = "Descarga del proyecto\n" + projectInfo.projectUrl;
        aboutExtraField.text = projectInfo.extraLines.join("\n");
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
        selectionField.text = selected + " seleccionadas para el ZIP";
    }

    function setStatus(text:String, color:Int):Void {
        statusColor = color;
        statusField.text = text;
        var rightEdge = infoButton != null ? infoButton.x - 14 : stage.stageWidth - 24;
        statusField.x = rightEdge - statusField.textWidth - 20;
        statusField.y = 34;

        statusBadge.graphics.clear();
        statusBadge.graphics.beginFill(statusColor, 0.95);
        statusBadge.graphics.drawRoundRect(rightEdge - statusField.textWidth - 36, 28, statusField.textWidth + 34, 28, 14, 14);
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

        layoutInfoButton(width, margin);

        var headerRight = infoButton.x - 18;
        titleField.x = margin;
        titleField.y = 24;
        titleField.width = Math.max(180, headerRight - margin);
        titleField.height = 40;

        subtitleField.x = margin;
        subtitleField.y = 70;
        subtitleField.width = Math.max(180, headerRight - margin);
        subtitleField.height = 42;

        var contentTop = headerHeight + margin;
        var gap = 18.0;

        if (width >= 980) {
            var fullWidth = width - margin * 2;
            var topCardWidth = (fullWidth - gap) * 0.5;
            var topHeight = Math.max(420.0, Math.min(620.0, height - contentTop - margin - 250));

            inputsCard.x = margin;
            inputsCard.y = contentTop;
            inputsCard.setSize(topCardWidth, topHeight);

            animationsCard.x = margin + topCardWidth + gap;
            animationsCard.y = contentTop;
            animationsCard.setSize(topCardWidth, topHeight);

            logCard.x = margin;
            logCard.y = contentTop + topHeight + gap;
            logCard.setSize(fullWidth, Math.max(220.0, height - logCard.y - margin));
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
        layoutAboutOverlay(width, height, margin);
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

        var buttonGap = 12.0;
        var refreshWidth = Math.max(154.0, (cardWidth - buttonGap) * 0.34);
        var exportWidth = Math.max(190.0, cardWidth - refreshWidth - buttonGap);
        refreshButton.x = 0;
        refreshButton.y = y;
        refreshButton.setSize(refreshWidth, 52);

        exportButton.x = refreshWidth + buttonGap;
        exportButton.y = y;
        exportButton.setSize(exportWidth, 52);
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

    function layoutInfoButton(width:Float, margin:Float):Void {
        var size = width < 900 ? 46.0 : 50.0;

        infoButtonBg.graphics.clear();
        infoButtonBg.graphics.beginFill(0x0F172A, 0.98);
        infoButtonBg.graphics.lineStyle(2, 0x38BDF8, 0.45);
        infoButtonBg.graphics.drawRoundRect(0, 0, size, size, 18, 18);
        infoButtonBg.graphics.endFill();

        infoButtonIcon.width = size - 18;
        infoButtonIcon.height = size - 18;
        infoButtonIcon.x = (size - infoButtonIcon.width) * 0.5;
        infoButtonIcon.y = (size - infoButtonIcon.height) * 0.5;

        infoButton.x = width - margin - size;
        infoButton.y = 24;
    }

    function layoutAboutOverlay(width:Float, height:Float, margin:Float):Void {
        aboutOverlay.visible = aboutVisible;

        aboutScrim.graphics.clear();
        aboutScrim.graphics.beginFill(0x020617, aboutVisible ? 0.80 : 0.0);
        aboutScrim.graphics.drawRect(0, 0, width, height);
        aboutScrim.graphics.endFill();

        var panelWidth = Math.min(620.0, width - margin * 2);
        var panelHeight = Math.min(540.0, height - margin * 2);
        if (panelHeight < 420) panelHeight = height - margin * 2;

        aboutCard.setSize(panelWidth, panelHeight);
        aboutCard.x = (width - panelWidth) * 0.5;
        aboutCard.y = (height - panelHeight) * 0.5;

        var contentWidth = aboutCard.innerWidth;
        var y = 0.0;

        aboutIntroField.x = 0;
        aboutIntroField.y = y;
        aboutIntroField.width = contentWidth;
        aboutIntroField.height = measuredTextHeight(aboutIntroField, 52);
        y += aboutIntroField.height + 10;

        aboutProjectField.x = 0;
        aboutProjectField.y = y;
        aboutProjectField.width = contentWidth;
        aboutProjectField.height = measuredTextHeight(aboutProjectField, 38);
        y += aboutProjectField.height + 14;

        aboutTeamList.x = 0;
        aboutTeamList.y = y;
        y += rebuildAboutTeamList(contentWidth) + 14;

        var buttonsY = aboutCard.innerHeight - 52;
        aboutExtraField.x = 0;
        aboutExtraField.y = y;
        aboutExtraField.width = contentWidth;
        aboutExtraField.height = Math.max(36, buttonsY - y - 12);

        var buttonGap = 12.0;
        var buttonWidth = (contentWidth - buttonGap) * 0.5;
        aboutLinkButton.x = 0;
        aboutLinkButton.y = buttonsY;
        aboutLinkButton.setSize(buttonWidth, 48);

        aboutCloseButton.x = buttonWidth + buttonGap;
        aboutCloseButton.y = buttonsY;
        aboutCloseButton.setSize(buttonWidth, 48);
    }

    function rebuildAboutTeamList(width:Float):Float {
        while (aboutTeamList.numChildren > 0) {
            aboutTeamList.removeChildAt(0);
        }

        if (projectInfo == null || projectInfo.teamEntries == null || projectInfo.teamEntries.length == 0) {
            return 0;
        }

        var y = 0.0;
        for (entry in projectInfo.teamEntries) {
            var row = createAboutTeamRow(entry, width);
            row.y = y;
            aboutTeamList.addChild(row);
            y += row.height + 10;
        }

        return y > 0 ? y - 10 : 0;
    }

    function createAboutTeamRow(entry:ProjectInfoEntryData, width:Float):Sprite {
        var row = new Sprite();
        var iconSize = 20.0;
        var textX = 0.0;

        if (entry != null && entry.icon != null && StringTools.trim(entry.icon) != "") {
            var assetPath = AppConfig.resolveAssetPath(entry.icon);
            try {
                if (openfl.Assets.exists(assetPath)) {
                    var icon = new Bitmap(openfl.Assets.getBitmapData(assetPath));
                    icon.smoothing = true;
                    icon.width = iconSize;
                    icon.height = iconSize;
                    icon.y = 1;
                    row.addChild(icon);
                    textX = iconSize + 10;
                }
            } catch (_:Dynamic) {}
        }

        var field = createAboutField(14, 0xF8FAFC, false);
        field.text = entry != null ? entry.text : "";
        field.x = textX;
        field.y = 0;
        field.width = Math.max(40, width - textX);
        field.height = measuredTextHeight(field, 20);
        row.addChild(field);

        return row;
    }

    function measuredTextHeight(field:TextField, minHeight:Float):Float {
        return Math.max(minHeight, field.textHeight + 10);
    }

    function toggleAbout(?force:Bool):Void {
        aboutVisible = force == null ? !aboutVisible : force;
        if (aboutVisible) {
            setChildIndex(aboutOverlay, numChildren - 1);
            refreshAboutText();
        }
        layout();
    }

    function openProjectLink():Void {
        if (projectInfo == null || StringTools.trim(projectInfo.projectUrl) == "") {
            appendLog("No hay link configurado para el proyecto.");
            setStatus("Sin link configurado", 0x7C2D12);
            return;
        }

        try {
            Lib.getURL(new URLRequest(projectInfo.projectUrl), "_blank");
            appendLog("Abriendo proyecto: " + projectInfo.projectUrl);
        } catch (error:Dynamic) {
            appendLog("No pude abrir el link del proyecto: " + Std.string(error));
            setStatus("No pude abrir el link", 0x7C2D12);
        }
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
