package android;

import android.AppLogger;
import android.AppModel.LoadResult;
import android.AppModel.ProjectPaths;
import android.UiComponents.AnimationListView;
import android.UiComponents.CardSection;
import android.UiComponents.UiBrowseMode;
import android.UiComponents.UiButton;
import android.UiComponents.UiInput;
import android.gestor.GestorArchivosBackend;
import android.gestor.ImportadorMediaBackend;
import android.AppConfig.ProjectInfoData;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;

class MainView extends Sprite {

    // ── Capas base ────────────────────────────────────────────────────────────
    var backgroundLayer:Shape;
    var accentLayer:Shape;

    // ── Header ────────────────────────────────────────────────────────────────
    var titleField:TextField;
    var subtitleField:TextField;
    var statusBadge:Shape;
    var statusField:TextField;

    // ── Navbar dropdown de proyectos (debajo del header) ─────────────────────
    var navbar:ProjectNavbar;
    var navbarY:Float = 0; // posición Y calculada en layout

    // ── Cards ─────────────────────────────────────────────────────────────────
    var inputsCard:CardSection;
    var animationsCard:CardSection;
    var logCard:CardSection;

    // ── Inputs de archivos ────────────────────────────────────────────────────
    var animationJsonInput:UiInput;
    var atlasJsonInput:UiInput;
    var atlasPngInput:UiInput;
    var animsXmlInput:UiInput;
    var animsJsonInput:UiInput;
    var filterInput:UiInput;

    // ── Controles ─────────────────────────────────────────────────────────────
    var mediaImportButton:UiButton;
    var refreshButton:UiButton;
    var mediaExportButton:UiButton;
    var exportButton:UiButton;
    var allButton:UiButton;
    var noneButton:UiButton;

    // ── Lista de animaciones ──────────────────────────────────────────────────
    var animationsView:AnimationListView;
    var selectionField:TextField;
    var helperField:TextField;

    // ── Consola visual (reemplaza logField anterior) ──────────────────────────
    var consoleView:ConsoleView;

    // ── Botón About ───────────────────────────────────────────────────────────
    var infoButton:Sprite;
    var infoButtonBg:Shape;
    var infoButtonIcon:Bitmap;
    var infoButtonFallback:Shape;

    // ── Overlay About ─────────────────────────────────────────────────────────
    var projectInfoOverlay:ProjectInfoOverlay;

    // ── Estado ────────────────────────────────────────────────────────────────
    var paths:ProjectPaths;
    var projectInfo:ProjectInfoData;
    var statusColor:Int = AppConfig.COLOR_BORDER;

    // ─────────────────────────────────────────────────────────────────────────
    //  Inicialización
    // ─────────────────────────────────────────────────────────────────────────

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
        stage.align     = StageAlign.TOP_LEFT;
        stage.color     = AppConfig.BACKGROUND_COLOR;

        paths       = Backend.createDefaultPaths();
        projectInfo = AppConfig.getProjectInfo();

        buildChrome();
        buildInputs();
        buildAnimations();
        buildLog();
        buildNavbar();
        buildAboutOverlay();

        stage.addEventListener(Event.RESIZE, onResize);
        layout();

        // Logs iniciales (van a AppLogger → llegan a ConsoleView automáticamente)
        AppLogger.log("Importa una carpeta completa o selecciona un proyecto desde Proyectos.");
        AppLogger.log("Los inputs manuales siguen disponibles por si necesitas rutas sueltas.");
        AppLogger.log("Entrada media: " + ImportadorMediaBackend.getMediaSpritemapsDir());
        AppLogger.log("Salida media:  " + ImportadorMediaBackend.getMediaProcessedDir());

        setStatus("Esperando archivos", 0x475569);

        // Escanear proyectos al inicio
        navbar.refresh();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Construcción de UI
    // ─────────────────────────────────────────────────────────────────────────

    function buildChrome():Void {
        backgroundLayer = new Shape();
        addChild(backgroundLayer);

        accentLayer = new Shape();
        addChild(accentLayer);

        titleField = new TextField();
        AppFonts.applyUi(titleField, 34, AppConfig.COLOR_TEXT, true);
        titleField.selectable   = false;
        titleField.mouseEnabled = false;
        titleField.text = AppConfig.APP_TITLE;
        addChild(titleField);

        subtitleField = new TextField();
        AppFonts.applyUi(subtitleField, 14, AppConfig.COLOR_MUTED);
        subtitleField.selectable   = false;
        subtitleField.mouseEnabled = false;
        subtitleField.multiline    = true;
        subtitleField.wordWrap     = true;
        subtitleField.text = AppConfig.APP_SUBTITLE;
        addChild(subtitleField);

        statusBadge = new Shape();
        addChild(statusBadge);

        statusField = new TextField();
        AppFonts.applyUi(statusField, 13, AppConfig.COLOR_TEXT, true);
        statusField.selectable   = false;
        statusField.mouseEnabled = false;
        statusField.autoSize     = TextFieldAutoSize.LEFT;
        addChild(statusField);

        inputsCard     = new CardSection("Archivos");
        animationsCard = new CardSection("Animaciones");
        logCard        = new CardSection("Consola");
        addChild(inputsCard);
        addChild(animationsCard);
        addChild(logCard);

        buildInfoButton();
    }

    function buildNavbar():Void {
        navbar = new ProjectNavbar();
        navbar.onProjectSelected = function(index:Int, folderPath:String) {
            loadProjectFromNavbar(index, folderPath);
        };
        addChild(navbar);
    }

    function buildInputs():Void {
        animationJsonInput = new UiInput("animations.json",      "Selecciona animations.json",        OPEN_FILE, "json", "Selecciona animations.json");
        atlasJsonInput     = new UiInput("spritemap.json",       "Selecciona spritemap.json",         OPEN_FILE, "json", "Selecciona spritemap.json");
        atlasPngInput      = new UiInput("spritemap.png",        "Se resuelve automáticamente.",      OPEN_FILE, "png",  "Selecciona spritemap.png");
        animsXmlInput      = new UiInput("anims.xml (opcional)", "Lista estilo Codename.",            OPEN_FILE, "xml",  "Selecciona anims.xml");
        animsJsonInput     = new UiInput("anims.json (opcional)","Lista estilo Psych/FNF.",           OPEN_FILE, "json", "Selecciona anims.json");
        filterInput        = new UiInput("Filtro", "Filtra por nombre o símbolo.", NONE);

        mediaImportButton  = new UiButton("Importar carpeta", AppConfig.COLOR_ACCENT);
        refreshButton      = new UiButton("Procesar", AppConfig.COLOR_ACCENT);
        mediaExportButton  = new UiButton("Exportar media", AppConfig.COLOR_ACCENT);
        exportButton       = new UiButton("Guardar ZIP", AppConfig.COLOR_ACCENT);
        allButton          = new UiButton("Todo", AppConfig.COLOR_ACCENT);
        noneButton         = new UiButton("Nada", AppConfig.COLOR_ACCENT);

        inputsCard.content.addChild(animationJsonInput); // no funciona de aqui
        inputsCard.content.addChild(atlasJsonInput);
        inputsCard.content.addChild(atlasPngInput);
        inputsCard.content.addChild(animsXmlInput);
        inputsCard.content.addChild(animsJsonInput); // a aqui
        inputsCard.content.addChild(mediaImportButton);
        inputsCard.content.addChild(refreshButton);
        inputsCard.content.addChild(mediaExportButton);
        inputsCard.content.addChild(exportButton);

        mediaImportButton.addEventListener(MouseEvent.CLICK, function(_) { importProjectFolder(); });
        refreshButton.addEventListener(MouseEvent.CLICK,     function(_) { refreshProject(); });
        mediaExportButton.addEventListener(MouseEvent.CLICK, function(_) { runExportToMedia(); });
        exportButton.addEventListener(MouseEvent.CLICK,      function(_) { runExport(); });

        filterInput.field.addEventListener(Event.CHANGE, function(_) {
            animationsView.setFilter(filterInput.text);
            updateSelectionSummary();
        });
    }

    function buildAnimations():Void {
        selectionField = new TextField();
        AppFonts.applyUi(selectionField, 13, AppConfig.COLOR_TEXT, true);
        selectionField.selectable   = false;
        selectionField.mouseEnabled = false;
        selectionField.text = "0 seleccionadas";
        animationsCard.content.addChild(selectionField);

        helperField = new TextField();
        AppFonts.applyUi(helperField, 12, AppConfig.COLOR_MUTED);
        helperField.selectable   = false;
        helperField.mouseEnabled = false;
        helperField.multiline    = true;
        helperField.wordWrap     = true;
        helperField.text = "Toca una fila para activarla/desactivarla. Desliza para hacer scroll.";
        animationsCard.content.addChild(helperField);

        animationsView = new AnimationListView();
        animationsView.onSelectionChanged = function() { updateSelectionSummary(); };
        animationsCard.content.addChild(animationsView);

        animationsCard.content.addChild(filterInput);
        animationsCard.content.addChild(allButton);
        animationsCard.content.addChild(noneButton);

        allButton.addEventListener(MouseEvent.CLICK,  function(_) { animationsView.setAllSelected(true); });
        noneButton.addEventListener(MouseEvent.CLICK, function(_) { animationsView.setAllSelected(false); });
    }

    function buildLog():Void {
        consoleView = new ConsoleView();
        logCard.content.addChild(consoleView);
    }

    function buildInfoButton():Void {
        infoButton = new Sprite();
        infoButton.buttonMode    = true;
        infoButton.useHandCursor = true;
        infoButton.mouseChildren = false;

        infoButtonBg = new Shape();
        infoButton.addChild(infoButtonBg);

        var iconData = AppConfig.getBitmapData(AppConfig.ABOUT_ICON_ASSET);
        if (iconData != null) {
            infoButtonIcon = new Bitmap(iconData);
            infoButtonIcon.smoothing = true;
            infoButton.addChild(infoButtonIcon);
        } else {
            AppLogger.warn("Icono About no encontrado: " + AppConfig.ABOUT_ICON_ASSET);
            infoButtonFallback = new Shape();
            infoButton.addChild(infoButtonFallback);
        }

        infoButton.addEventListener(MouseEvent.CLICK, function(_) { projectInfoOverlay.toggle(); });
        addChild(infoButton);
    }

    function buildAboutOverlay():Void {
        projectInfoOverlay = new ProjectInfoOverlay(projectInfo);
        projectInfoOverlay.onStatus = function(text:String, color:Int) {
            setStatus(text, color);
        };
        addChild(projectInfoOverlay);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Lógica de negocio
    // ─────────────────────────────────────────────────────────────────────────

    /** Cargar proyecto seleccionado desde el navbar. */
    function loadProjectFromNavbar(index:Int, folderPath:String):Void {
        setStatus("Cargando proyecto #" + (index + 1) + "…", 0x0F766E);
        try {
            var newPaths = ImportadorMediaBackend.loadProjectFromDirectory(folderPath);
            populateInputsFromPaths(newPaths);
            refreshProject();
        } catch (error:Dynamic) {
            AppLogger.err("Error cargando proyecto: " + Std.string(error));
            setStatus("No pude cargar el proyecto", 0x7C2D12);
        }
    }

    function loadProjectFromMedia():Void {
        setStatus("Buscando en media/spritemaps...", 0x0F766E);
        try {
            AppLogger.log(ImportadorMediaBackend.describeImport());
            var mediaPaths = ImportadorMediaBackend.loadProject();
            populateInputsFromPaths(mediaPaths);
            refreshProject();
        } catch (error:Dynamic) {
            AppLogger.err("Carga desde media falló: " + Std.string(error));
            setStatus("No encontré proyecto en media", 0x7C2D12);
        }
    }

    function importProjectFolder():Void {
        setStatus("Elige una carpeta de spritemap", AppConfig.COLOR_ACCENT);
        mediaImportButton.enabled = false;

        var opened = GestorArchivosBackend.importDirectoryToSpritemaps(
            "Importar carpeta de spritemap",
            function(importedPath:String) {
                mediaImportButton.enabled = true;
                AppLogger.log("Importada en: " + importedPath);

                try {
                    navbar.refresh();
                    var importedPaths = ImportadorMediaBackend.loadFirstProjectUnder(importedPath);
                    populateInputsFromPaths(importedPaths);
                    refreshProject();
                    setStatus("Carpeta importada", 0x15803D);
                } catch (error:Dynamic) {
                    AppLogger.err("La carpeta se copió, pero no encontré un proyecto válido: " + Std.string(error));
                    setStatus("Importada, faltan archivos", 0x7C2D12);
                }
            },
            function(message:String) {
                mediaImportButton.enabled = true;
                AppLogger.err("Importar carpeta falló: " + message);
                setStatus("No pude importar carpeta", 0x7C2D12);
            }
        );

        if (!opened) {
            mediaImportButton.enabled = true;
            setStatus("Selector no disponible", 0x7C2D12);
        }
    }

    function refreshProject():Void {
        syncPathsFromInputs();
        setStatus("Leyendo proyecto...", 0x1D4ED8);
        try {
            var result:LoadResult = Backend.loadProject(paths);
            animationsView.setItems(result.animations);
            animationsView.setFilter(filterInput.text);
            updateSelectionSummary();
            AppLogger.log(result.log);
            setStatus("Animaciones listas", result.animations.length > 0 ? 0x0F766E : 0x475569);
        } catch (error:Dynamic) {
            AppLogger.err("Refresh falló: " + Std.string(error));
            setStatus("Error leyendo rutas", 0x7C2D12);
        }
    }

    function runExport():Void {
        syncPathsFromInputs();
        setStatus("Procesando export...", 0xC2410C);
        exportButton.enabled      = false;
        mediaExportButton.enabled = false;

        try {
            var result = Backend.exportProject(paths, animationsView.getSelectedItems(), false);
            if (result.log != "") AppLogger.log(result.log);

            if (result.filesWritten <= 0 || result.archivePath == "") {
                setStatus("Nada exportado", 0x7C2D12);
                exportButton.enabled = mediaExportButton.enabled = true;
                return;
            }

            setStatus("Elige dónde guardar el ZIP", 0x2563EB);
            var opened = GestorArchivosBackend.saveFileToUser(
                AppConfig.SAVE_DIALOG_TITLE,
                result.archiveName,
                result.archivePath,
                function(savedFile) {
                    AppLogger.log("ZIP guardado: " + savedFile.targetPath);
                    Backend.cleanupAfterSave();
                    resetAfterSuccessfulSave();
                    setStatus("ZIP guardado", 0x15803D);
                    exportButton.enabled = mediaExportButton.enabled = true;
                },
                function(message:String) {
                    AppLogger.err("No pude guardar el ZIP: " + message);
                    setStatus("ZIP listo para reintentar", 0x7C2D12);
                    exportButton.enabled = mediaExportButton.enabled = true;
                }
            );

            if (!opened) {
                AppLogger.err("No pude abrir el selector para guardar.");
                setStatus("Error al guardar", 0x7C2D12);
                exportButton.enabled = mediaExportButton.enabled = true;
            }
        } catch (error:Dynamic) {
            AppLogger.err("Export falló: " + Std.string(error));
            setStatus("Export falló", 0x7C2D12);
            exportButton.enabled = mediaExportButton.enabled = true;
        }
    }

    function runExportToMedia():Void {
        syncPathsFromInputs();
        setStatus("Exportando a media/processed...", 0x7C3AED);
        exportButton.enabled = mediaExportButton.enabled = false;

        try {
            var result = Backend.exportProjectToMedia(paths, animationsView.getSelectedItems(), false);
            if (result.log != "") AppLogger.log(result.log);

            if (result.filesWritten <= 0 || result.archivePath == "") {
                setStatus("Nada exportado", 0x7C2D12);
                exportButton.enabled = mediaExportButton.enabled = true;
                return;
            }

            AppLogger.log("Salida procesada: " + result.outputDir);
            AppLogger.log("ZIP en media: "      + result.archivePath);
            setStatus("Listo en media/processed", 0x15803D);
            exportButton.enabled = mediaExportButton.enabled = true;
        } catch (error:Dynamic) {
            AppLogger.err("Export a media falló: " + Std.string(error));
            setStatus("Falló export a media", 0x7C2D12);
            exportButton.enabled = mediaExportButton.enabled = true;
        }
    }

    function resetAfterSuccessfulSave():Void {
        paths = Backend.createDefaultPaths();
        animationJsonInput.text = "";
        atlasJsonInput.text = "";
        atlasPngInput.text  = "";
        animsXmlInput.text  = "";
        animsJsonInput.text = "";
        filterInput.text    = "";
        animationsView.setItems([]);
        updateSelectionSummary();
        AppLogger.log("Workspace temporal limpiado.");
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function syncPathsFromInputs():Void {
        paths.animationJson = animationJsonInput.text;
        paths.atlasJson     = atlasJsonInput.text;
        paths.atlasPng      = atlasPngInput.text;
        paths.animsXml      = animsXmlInput.text;
        paths.animsJson     = animsJsonInput.text;
        paths.outputDir     = Backend.getProcessingOutputDir();
    }

    function populateInputsFromPaths(newPaths:ProjectPaths):Void {
        if (newPaths == null) return;
        animationJsonInput.text = newPaths.animationJson;
        atlasJsonInput.text     = newPaths.atlasJson;
        atlasPngInput.text      = newPaths.atlasPng;
        animsXmlInput.text      = newPaths.animsXml;
        animsJsonInput.text     = newPaths.animsJson;
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
        statusBadge.graphics.beginFill(AppConfig.COLOR_SURFACE, 1);
        statusBadge.graphics.lineStyle(3, statusColor, 1);
        statusBadge.graphics.drawRect(rightEdge - statusField.textWidth - 36, 28,
            statusField.textWidth + 34, 30);
        statusBadge.graphics.endFill();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Layout
    // ─────────────────────────────────────────────────────────────────────────

    function onResize(_:Event):Void { layout(); }

    function layout():Void {
        var width  = stage.stageWidth;
        var height = stage.stageHeight;
        var margin:Float = 18.0;

        drawBackground(width, height);

        layoutInfoButton(margin, width);

        // ── Header ────────────────────────────────────────────────────────────
        var headerRight = infoButton.x - 14;
        drawHeaderFrames(width, height, margin, headerRight);

        titleField.x      = margin + 18;
        titleField.y      = 14;
        titleField.width  = Math.max(180, Math.min(360, headerRight - margin - 18));
        titleField.height = 42;

        subtitleField.x      = margin + 18;
        subtitleField.y      = 60;
        subtitleField.width  = Math.max(180, Math.min(360, headerRight - margin - 18));
        subtitleField.height = 38;

        // ── Navbar dropdown — debajo del subtítulo ────────────────────────────
        navbarY = subtitleField.y + 44;
        navbar.x = margin;
        navbar.y = navbarY;
        navbar.setStageWidth(width);

        // ── Cards — empiezan debajo del navbar ────────────────────────────────
        var contentTop = navbarY + 52;
        var gap  = 14.0;
        var fullW = width - margin * 2;
        var compactLayout = width < 960;

        if (width >= 680) {
            var topCardW = (fullW - gap) * 0.5;
            var availableH = Math.max(540.0, height - contentTop - margin);
            var inputsH = clamp(availableH * 0.46, 540.0, 620.0);
            var animsH = clamp(availableH * 0.42, 390.0, 520.0);

            inputsCard.x = margin;
            inputsCard.y = contentTop;
            inputsCard.setSize(topCardW, inputsH);

            animationsCard.x = margin + topCardW + gap;
            animationsCard.y = contentTop;
            animationsCard.setSize(topCardW, animsH);

            logCard.x = margin;
            logCard.y = contentTop + Math.max(inputsH, animsH) + gap;
            logCard.setSize(fullW, Math.max(220.0, height - logCard.y - margin));
        } else {
            var availableH = Math.max(420.0, height - contentTop - margin);
            var splitBottom = width >= 620 && availableH >= 760;

            if (splitBottom) {
                var inputsH = clamp(availableH * 0.48, 540.0, 600.0);
                var bottomH = Math.max(220.0, availableH - inputsH - gap);
                var bottomW = (fullW - gap) * 0.5;

                inputsCard.x = margin;
                inputsCard.y = contentTop;
                inputsCard.setSize(fullW, inputsH);

                animationsCard.x = margin;
                animationsCard.y = contentTop + inputsH + gap;
                animationsCard.setSize(bottomW, bottomH);

                logCard.x = margin + bottomW + gap;
                logCard.y = animationsCard.y;
                logCard.setSize(bottomW, bottomH);
            } else {
                var inputsH = clamp(availableH * 0.46, 430.0, 560.0);
                var remainingH = Math.max(220.0, availableH - inputsH - gap * 2);
                var animsH = Math.max(160.0, remainingH * 0.52);
                var logH = Math.max(140.0, availableH - inputsH - animsH - gap * 2);

                inputsCard.x = margin;
                inputsCard.y = contentTop;
                inputsCard.setSize(fullW, inputsH);

                animationsCard.x = margin;
                animationsCard.y = contentTop + inputsH + gap;
                animationsCard.setSize(fullW, animsH);

                logCard.x = margin;
                logCard.y = animationsCard.y + animsH + gap;
                logCard.setSize(fullW, Math.max(120.0, height - logCard.y - margin));
            }
        }

        setInputsCompact(compactLayout);
        layoutInputsCard();
        layoutAnimationsCard();
        layoutLogCard();
        projectInfoOverlay.layoutOverlay(width, height, margin);
        setStatus(statusField.text == null || statusField.text == "" ? "Listo" : statusField.text, statusColor);
    }

    function layoutInfoButton(margin:Float, width:Float):Void {
        var size = 46.0;

        infoButtonBg.graphics.clear();
        infoButtonBg.graphics.beginFill(AppConfig.COLOR_SURFACE, 1);
        infoButtonBg.graphics.lineStyle(3, AppConfig.COLOR_ACCENT, 1);
        infoButtonBg.graphics.drawRect(0, 0, size, size);
        infoButtonBg.graphics.endFill();

        if (infoButtonIcon != null) {
            infoButtonIcon.width  = size - 18;
            infoButtonIcon.height = size - 18;
            infoButtonIcon.x = (size - infoButtonIcon.width)  * 0.5;
            infoButtonIcon.y = (size - infoButtonIcon.height) * 0.5;
        }

        if (infoButtonFallback != null) {
            infoButtonFallback.graphics.clear();
            infoButtonFallback.graphics.beginFill(AppConfig.COLOR_TEXT);
            infoButtonFallback.graphics.drawCircle(size * 0.5, size * 0.34, 3);
            infoButtonFallback.graphics.drawRoundRect(size * 0.5 - 2, size * 0.46, 4, 15, 2, 2);
            infoButtonFallback.graphics.endFill();
        }

        infoButton.x = width - margin - size;
        infoButton.y = 24;
    }

    function layoutInputsCard():Void {
        var cardWidth = inputsCard.innerWidth;
        var y = 0.0;
        var compact = stage.stageWidth < 960 || inputsCard.innerHeight < 620;
        var rowGap = compact ? 61.0 : 88.0;

        for (input in [animationJsonInput, atlasJsonInput, atlasPngInput, animsXmlInput, animsJsonInput]) {
            input.setCompact(compact);
            input.x = 0;
            input.y = y;
            input.setWidth(cardWidth);
            y += rowGap;
        }

        var buttonGap = 12.0;
        var buttonW   = (cardWidth - buttonGap) * 0.5;
        var buttonH   = compact ? 46.0 : 52.0;

        mediaImportButton.x = 0;
        mediaImportButton.y = y;
        mediaImportButton.setSize(buttonW, buttonH);

        refreshButton.x = buttonW + buttonGap;
        refreshButton.y = y;
        refreshButton.setSize(buttonW, buttonH);
        y += buttonH + 12;

        mediaExportButton.x = 0;
        mediaExportButton.y = y;
        mediaExportButton.setSize(buttonW, buttonH);

        exportButton.x = buttonW + buttonGap;
        exportButton.y = y;
        exportButton.setSize(buttonW, buttonH);
    }

    function layoutAnimationsCard():Void {
        var compact = animationsCard.innerWidth < 380 || animationsCard.innerHeight < 320;
        selectionField.x = 0;
        selectionField.y = 0;
        selectionField.width  = animationsCard.innerWidth;
        selectionField.height = 20;

        filterInput.setCompact(compact);
        filterInput.x = 0;
        filterInput.y = compact ? 24 : 26;
        filterInput.setWidth(animationsCard.innerWidth);

        var actionsY  = compact ? 92.0 : 116.0;
        var buttonW   = (animationsCard.innerWidth - 10) * 0.5;
        var buttonH   = compact ? 40.0 : 46.0;

        allButton.x  = 0;
        allButton.y  = actionsY;
        allButton.setSize(buttonW, buttonH);

        noneButton.x = buttonW + 10;
        noneButton.y = actionsY;
        noneButton.setSize(buttonW, buttonH);

        helperField.x = 0;
        helperField.y = compact ? 140 : 170;
        helperField.width  = animationsCard.innerWidth;
        helperField.height = compact ? 30 : 36;

        animationsView.x = 0;
        animationsView.y = compact ? 176 : 214;
        animationsView.setSize(animationsCard.innerWidth, Math.max(60, animationsCard.innerHeight - animationsView.y));
    }

    function layoutLogCard():Void {
        consoleView.setSize(logCard.innerWidth, logCard.innerHeight);
    }

    function drawBackground(width:Float, height:Float):Void {
        backgroundLayer.graphics.clear();
        backgroundLayer.graphics.beginFill(AppConfig.BACKGROUND_COLOR);
        backgroundLayer.graphics.drawRect(0, 0, width, height);
        backgroundLayer.graphics.endFill();

        accentLayer.graphics.clear();
    }

    function drawHeaderFrames(width:Float, height:Float, margin:Float, headerRight:Float):Void {
        accentLayer.graphics.clear();
        accentLayer.graphics.lineStyle(4, AppConfig.COLOR_BORDER, 1);
        accentLayer.graphics.beginFill(AppConfig.COLOR_SURFACE, 1);
        accentLayer.graphics.drawRect(margin - 8, 4, Math.min(390, Math.max(280, headerRight - margin + 4)), 116);
        accentLayer.graphics.endFill();
    }

    function setInputsCompact(value:Bool):Void {
        for (input in [animationJsonInput, atlasJsonInput, atlasPngInput, animsXmlInput, animsJsonInput, filterInput]) {
            if (input != null) input.setCompact(value);
        }
    }

    function clamp(value:Float, min:Float, max:Float):Float {
        return Math.max(min, Math.min(max, value));
    }
}
