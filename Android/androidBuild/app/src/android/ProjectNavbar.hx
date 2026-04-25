package android;

import android.AppLogger;
import android.AppConfig;
import android.gestor.GestorArchivosBackend;
import haxe.io.Path;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

#if sys
import sys.FileSystem;
#end

// ─── Info de una carpeta escaneada ───────────────────────────────────────────

class ProjectEntry {
    public var folderPath:String;
    public var folderName:String;
    public var hasAnimations:Bool;
    public var hasSpritemap:Bool;
    public var hasPng:Bool;

    public function new(folderPath:String) {
        this.folderPath    = folderPath;
        this.folderName    = Path.withoutDirectory(folderPath);
        this.hasAnimations = GestorArchivosBackend.fileExists(Path.join([folderPath, AppConfig.REQUIRED_FILE_1]));
        this.hasSpritemap  = GestorArchivosBackend.fileExists(Path.join([folderPath, AppConfig.REQUIRED_FILE_2]));
        this.hasPng        = GestorArchivosBackend.fileExists(Path.join([folderPath, AppConfig.REQUIRED_FILE_3]));
    }

    public var isComplete(get, never):Bool;
    function get_isComplete() return hasAnimations && hasSpritemap && hasPng;

    public function missingList():Array<String> {
        var m = [];
        if (!hasAnimations) m.push(AppConfig.REQUIRED_FILE_1);
        if (!hasSpritemap)  m.push(AppConfig.REQUIRED_FILE_2);
        if (!hasPng)        m.push(AppConfig.REQUIRED_FILE_3);
        return m;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
/**
 * ProjectNavbar  —  Dropdown de proyectos debajo del header.
 *
 * Uso en MainView:
 *   navbar = new ProjectNavbar();
 *   navbar.onProjectSelected = function(i, path) { ... };
 *   addChild(navbar);
 *   navbar.x = margin;
 *   navbar.y = subtitleField.y + subtitleField.height + 10;
 *   navbar.setStageWidth(stage.stageWidth);
 *   navbar.refresh();
 */
class ProjectNavbar extends Sprite {

    public var onProjectSelected:Int->String->Void = null;

    // ── Layout ───────────────────────────────────────────────────────────────
    var _stageW:Float = 800;

    // ── Botón disparador ─────────────────────────────────────────────────────
    var _triggerBtn:Sprite;
    var _triggerBg:Shape;
    var _triggerLabel:TextField;

    // ── Panel dropdown ───────────────────────────────────────────────────────
    var _panel:Sprite;
    var _panelBg:Shape;
    var _list:Sprite;
    var _emptyField:TextField;

    // Scrim transparente que cierra el panel si tocas fuera
    var _scrim:Sprite;

    // ── Estado ───────────────────────────────────────────────────────────────
    var _entries:Array<ProjectEntry> = [];
    var _open:Bool = false;
    var _selectedIndex:Int = -1;

    static inline var BTN_H:Float       = 38;
    static inline var BTN_PAD:Float     = 14;
    static inline var ROW_H:Float       = 52;
    static inline var ROW_GAP:Float     = 4;
    static inline var PANEL_MAX_H:Float = 320;
    static inline var PANEL_W:Float     = 430;
    static inline var CORNER:Float      = 10;

    static inline var C_OK_BG:Int   = 0x14532D;
    static inline var C_OK_TXT:Int  = 0x86EFAC;
    static inline var C_ERR_BG:Int  = 0x450A0A;
    static inline var C_ERR_TXT:Int = 0xFCA5A5;
    static inline var C_SEL_BG:Int  = 0x1E3A5F;
    static inline var C_PANEL:Int   = 0x0D1526;

    public function new() {
        super();
        _build();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  API pública
    // ─────────────────────────────────────────────────────────────────────────

    public function setStageWidth(w:Float):Void {
        _stageW = w;
        _drawTrigger();
    }

    public function refresh():Void {
        _entries = [];

        #if sys
        var root = android.gestor.ImportadorMediaBackend.getMediaSpritemapsDir();
        if (GestorArchivosBackend.directoryExists(root)) {
            var dirs:Array<String> = [];
            _collectDirs(root, dirs, 0, 3);
            dirs.sort(GestorArchivosBackend.compareStrings);
            for (d in dirs) _entries.push(new ProjectEntry(d));
        }
        #end

        var total    = _entries.length;
        var complete = _entries.filter(function(e) return e.isComplete).length;
        AppLogger.log("Navbar: " + total + " carpeta(s), " + complete + " completa(s).");

        _selectedIndex = -1;
        _updateLabel();
        if (_open) _rebuildRows();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Build
    // ─────────────────────────────────────────────────────────────────────────

    function _build():Void {
        // Scrim — capa invisible para cerrar al tocar fuera
        _scrim = new Sprite();
        _scrim.visible = false;
        _scrim.addEventListener(MouseEvent.CLICK, function(_) { _close(); });
        addChild(_scrim);

        // Botón
        _triggerBtn = new Sprite();
        _triggerBtn.buttonMode    = true;
        _triggerBtn.useHandCursor = true;
        _triggerBtn.mouseChildren = false;

        _triggerBg = new Shape();
        _triggerBtn.addChild(_triggerBg);

        _triggerLabel = new TextField();
        AppFonts.applyUi(_triggerLabel, 13, 0xE2E8F0, true);
        _triggerLabel.selectable   = false;
        _triggerLabel.mouseEnabled = false;
        _triggerLabel.autoSize     = openfl.text.TextFieldAutoSize.LEFT;
        _triggerLabel.text = "📁 Proyectos ▾";
        _triggerBtn.addChild(_triggerLabel);

        _triggerBtn.addEventListener(MouseEvent.CLICK, function(_) {
            if (_open) _close(); else _openPanel();
        });
        addChild(_triggerBtn);

        // Panel
        _panel = new Sprite();
        _panel.visible = false;
        addChild(_panel);

        _panelBg = new Shape();
        _panel.addChild(_panelBg);

        _list = new Sprite();
        _panel.addChild(_list);

        _emptyField = new TextField();
        AppFonts.applyUi(_emptyField, 12, 0x64748B);
        _emptyField.selectable   = false;
        _emptyField.mouseEnabled = false;
        _emptyField.multiline    = true;
        _emptyField.wordWrap     = true;
        _panel.addChild(_emptyField);

        _drawTrigger();
    }

    function _drawTrigger():Void {
        var tw = _triggerLabel.textWidth + BTN_PAD * 2 + 10;
        _triggerBg.graphics.clear();
        _triggerBg.graphics.beginFill(_open ? 0x1D4ED8 : 0x1E293B);
        _triggerBg.graphics.drawRoundRect(0, 0, tw, BTN_H, CORNER, CORNER);
        _triggerBg.graphics.endFill();
        _triggerLabel.x = BTN_PAD;
        _triggerLabel.y = (BTN_H - 18) * 0.5 - 2;
    }

    function _updateLabel():Void {
        var total    = _entries.length;
        var complete = _entries.filter(function(e) return e.isComplete).length;
        _triggerLabel.text = "📁 Proyectos (" + complete + "/" + total + ") " + (_open ? "▴" : "▾");
        _drawTrigger();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Open / Close
    // ─────────────────────────────────────────────────────────────────────────

    function _openPanel():Void {
        _open = true;
        _updateLabel();
        _rebuildRows();
        _panel.visible = true;

        // Panel justo debajo del botón
        _panel.x = 0;
        _panel.y = BTN_H + 4;

        // Ajustar si se sale por la derecha
        var globalX = this.x;
        if (globalX + PANEL_W > _stageW - 8) {
            _panel.x = _stageW - 8 - PANEL_W - globalX;
        }

        // Scrim gigante debajo del panel para capturar toques fuera
        _scrim.visible = true;
        var sg = _scrim.graphics;
        sg.clear();
        sg.beginFill(0x000000, 0.01);
        sg.drawRect(-this.x - 10, -this.y - 10, _stageW + 20, 6000);
        sg.endFill();

        // Subir al tope del display list del padre
        if (parent != null) parent.setChildIndex(this, parent.numChildren - 1);
    }

    function _close():Void {
        _open          = false;
        _panel.visible = false;
        _scrim.visible = false;
        _updateLabel();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Filas
    // ─────────────────────────────────────────────────────────────────────────

    function _rebuildRows():Void {
        while (_list.numChildren > 0) _list.removeChildAt(0);

        var isEmpty = (_entries.length == 0);
        _emptyField.visible = isEmpty;
        _emptyField.x = 12;
        _emptyField.y = 12;
        _emptyField.width  = PANEL_W - 24;
        _emptyField.height = 50;
        _emptyField.text   = "No hay carpetas en:\n" + android.gestor.ImportadorMediaBackend.getMediaSpritemapsDir();

        var y = 8.0;
        for (i in 0..._entries.length) {
            var row = _makeRow(i, _entries[i]);
            row.y = y;
            _list.addChild(row);
            y += ROW_H + ROW_GAP;
        }

        var contentH = isEmpty ? 74.0 : (y + 8);
        var panelH   = Math.min(contentH, PANEL_MAX_H);

        _panelBg.graphics.clear();
        _panelBg.graphics.beginFill(C_PANEL, 0.98);
        _panelBg.graphics.lineStyle(1, 0x1E3A5F, 0.8);
        _panelBg.graphics.drawRoundRect(0, 0, PANEL_W, panelH, CORNER, CORNER);
        _panelBg.graphics.endFill();
    }

    function _makeRow(index:Int, entry:ProjectEntry):Sprite {
        var isSelected = (index == _selectedIndex);
        var isOk       = entry.isComplete;

        var row = new Sprite();
        row.mouseChildren = false;
        if (isOk) { row.buttonMode = true; row.useHandCursor = true; }

        // Fondo
        var bg = new Shape();
        var bgColor = isSelected ? C_SEL_BG : (isOk ? C_OK_BG : C_ERR_BG);
        bg.graphics.beginFill(bgColor, 0.92);
        bg.graphics.drawRoundRect(8, 0, PANEL_W - 16, ROW_H, 8, 8);
        bg.graphics.endFill();
        row.addChild(bg);

        // Dot de estado
        var dot = new Shape();
        dot.graphics.beginFill(isOk ? 0x4ADE80 : 0xF87171);
        dot.graphics.drawCircle(22, ROW_H * 0.5, 6);
        dot.graphics.endFill();
        row.addChild(dot);

        // Nombre
        var nameW:Float = isOk ? (PANEL_W - 50) : (PANEL_W - 54) * 0.52;
        var nameField = new TextField();
        AppFonts.applyUi(nameField, 14, isOk ? C_OK_TXT : 0xE2E8F0, true);
        nameField.selectable   = false;
        nameField.mouseEnabled = false;
        nameField.text  = entry.folderName;
        nameField.x     = 36;
        nameField.y     = isOk ? (ROW_H - 20) * 0.5 - 2 : 7;
        nameField.width  = nameW;
        nameField.height = 20;
        row.addChild(nameField);

        // Archivos faltantes (solo si incompleto)
        if (!isOk) {
            var missing  = entry.missingList();
            var errField = new TextField();
            AppFonts.applyUi(errField, 11, C_ERR_TXT);
            errField.selectable   = false;
            errField.mouseEnabled = false;
            errField.multiline    = true;
            errField.wordWrap     = true;
            errField.text   = "Falta:\n" + missing.join(", ");
            errField.x      = 36 + nameW + 8;
            errField.y      = 5;
            errField.width  = PANEL_W - 36 - nameW - 20;
            errField.height = ROW_H - 10;
            row.addChild(errField);
        }

        // Eventos
        if (isOk) {
            row.addEventListener(MouseEvent.CLICK, function(_) {
                _selectedIndex = index;
                _close();
                AppLogger.log("Proyecto cargado: " + entry.folderPath);
                if (onProjectSelected != null) onProjectSelected(index, entry.folderPath);
            });
            row.addEventListener(MouseEvent.ROLL_OVER, function(_) { bg.alpha = 0.65; });
            row.addEventListener(MouseEvent.ROLL_OUT,  function(_) { bg.alpha = 1.0; });
        }

        return row;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Escaneo
    // ─────────────────────────────────────────────────────────────────────────

    function _collectDirs(path:String, out:Array<String>, depth:Int, max:Int):Void {
        #if sys
        if (!GestorArchivosBackend.directoryExists(path)) return;

        // Incluir si tiene al menos 1 archivo requerido (para mostrar incompletas)
        if (_hasAnyRequired(path)) { out.push(path); return; }
        if (depth >= max) return;

        try {
            var children = FileSystem.readDirectory(path);
            children.sort(GestorArchivosBackend.compareStrings);
            for (entry in children) {
                var child = Path.join([path, entry]);
                if (GestorArchivosBackend.directoryExists(child))
                    _collectDirs(child, out, depth + 1, max);
            }
        } catch (_:Dynamic) {}
        #end
    }

    function _hasAnyRequired(path:String):Bool {
        return GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_1]))
            || GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_2]))
            || GestorArchivosBackend.fileExists(Path.join([path, AppConfig.REQUIRED_FILE_3]));
    }
}
