package android;

import android.AppLogger;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * ConsoleView
 *
 * Caja visual que muestra los logs de AppLogger en tiempo real.
 * Se suscribe sola al AppLogger.onLine al ser añadida al stage.
 *
 * Características:
 *   - Scroll automático al fondo al llegar un mensaje nuevo.
 *   - Scroll manual con rueda del ratón / arrastre.
 *   - Colores por nivel: LOG → blanco, WRN → amarillo, ERR → rojo.
 *   - Botón "Limpiar" integrado.
 *   - Si la UI se crea DESPUÉS de que ya hayan llegado logs,
 *     hidrata automáticamente desde AppLogger.lines.
 *
 * Uso en MainView:
 *   var console = new ConsoleView();
 *   addChild(console);
 *   console.setSize(logCard.innerWidth, logCard.innerHeight);
 */
class ConsoleView extends Sprite {

    // ── Config visual ─────────────────────────────────────────────────────────
    static inline var FONT_SIZE:Int     = 13;
    static inline var LINE_H:Float      = 18;
    static inline var PADDING:Float     = 10;
    static inline var BTN_H:Float       = 32;
    static inline var BTN_W:Float       = 80;

    static inline var COLOR_LOG:Int     = 0xE2E8F0;
    static inline var COLOR_WARN:Int    = 0xFBBF24;
    static inline var COLOR_ERR:Int     = 0xF87171;
    static inline var COLOR_BG:Int      = 0x050D1A;
    static inline var COLOR_CLEAR_BTN:Int = 0x334155;

    // ── Internos ──────────────────────────────────────────────────────────────
    var _bg:Shape;
    var _viewport:Sprite;
    var _content:Sprite;
    var _mask:Shape;
    var _clearBtn:Sprite;
    var _clearBg:Shape;
    var _clearLabel:TextField;

    var _w:Float = 400;
    var _h:Float = 200;
    var _scrollY:Float = 0;
    var _pressing:Bool  = false;
    var _dragY0:Float   = 0;
    var _scrollY0:Float = 0;

    // Filas actuales (TextField por línea)
    var _rows:Array<TextField> = [];

    public function new() {
        super();
        _build();

        if (stage != null) _init();
        else addEventListener(Event.ADDED_TO_STAGE, _onAdded);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  API pública
    // ─────────────────────────────────────────────────────────────────────────

    public function setSize(w:Float, h:Float):Void {
        _w = w;
        _h = h;
        _draw();
        _updateScroll();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Inicialización
    // ─────────────────────────────────────────────────────────────────────────

    function _onAdded(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, _onAdded);
        _init();
    }

    function _init():Void {
        // Hidratar con los logs que ya existen antes de que la UI apareciese
        for (line in AppLogger.lines) _addRow(line);
        _scrollToBottom();

        // Suscribirse a logs nuevos
        AppLogger.onLine = function(line:String) {
            if (line == "") {
                // señal de "limpiar"
                _clearRows();
                return;
            }
            _addRow(line);
            _scrollToBottom();
        };

        // Eventos de scroll táctil / rueda
        _viewport.addEventListener(MouseEvent.MOUSE_WHEEL, _onWheel);
        _viewport.addEventListener(MouseEvent.MOUSE_DOWN,  _onDown);
        stage.addEventListener(MouseEvent.MOUSE_UP,   _onUp);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, _onMove);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Construcción visual
    // ─────────────────────────────────────────────────────────────────────────

    function _build():Void {
        _bg = new Shape();
        addChild(_bg);

        _viewport = new Sprite();
        addChild(_viewport);

        _content = new Sprite();
        _viewport.addChild(_content);

        _mask = new Shape();
        addChild(_mask);
        _viewport.mask = _mask;

        // Botón limpiar
        _clearBtn = new Sprite();
        _clearBtn.buttonMode    = true;
        _clearBtn.useHandCursor = true;
        _clearBtn.mouseChildren = false;

        _clearBg = new Shape();
        _clearBtn.addChild(_clearBg);

        _clearLabel = new TextField();
        AppFonts.applyUi(_clearLabel, 12, 0xFFFFFF, true);
        _clearLabel.selectable   = false;
        _clearLabel.mouseEnabled = false;
        _clearLabel.text = "Limpiar";
        _clearBtn.addChild(_clearLabel);
        addChild(_clearBtn);

        _clearBtn.addEventListener(MouseEvent.CLICK, function(_) {
            AppLogger.clear();
        });

        _draw();
    }

    function _draw():Void {
        // Fondo
        _bg.graphics.clear();
        _bg.graphics.beginFill(COLOR_BG);
        _bg.graphics.drawRoundRect(0, 0, _w, _h, 12, 12);
        _bg.graphics.endFill();

        // Máscara viewport
        _mask.graphics.clear();
        _mask.graphics.beginFill(0xFFFFFF);
        _mask.graphics.drawRect(0, 0, _w, _h - BTN_H - 6);
        _mask.graphics.endFill();

        _viewport.x = PADDING;
        _viewport.y = PADDING;

        // Botón limpiar
        _clearBg.graphics.clear();
        _clearBg.graphics.beginFill(COLOR_CLEAR_BTN);
        _clearBg.graphics.drawRoundRect(0, 0, BTN_W, BTN_H, 10, 10);
        _clearBg.graphics.endFill();

        _clearLabel.x = (BTN_W - _clearLabel.textWidth) * 0.5 - 2;
        _clearLabel.y = (BTN_H - _clearLabel.textHeight) * 0.5 - 3;
        _clearLabel.width  = BTN_W;
        _clearLabel.height = BTN_H;

        _clearBtn.x = _w - BTN_W - PADDING;
        _clearBtn.y = _h - BTN_H - 4;

        // Relayout de filas
        _relayoutRows();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Manejo de filas
    // ─────────────────────────────────────────────────────────────────────────

    function _addRow(line:String):Void {
        var color = COLOR_LOG;
        if (StringTools.startsWith(line, "[WRN]")) color = COLOR_WARN;
        else if (StringTools.startsWith(line, "[ERR]")) color = COLOR_ERR;

        var tf = new TextField();
        AppFonts.applyMono(tf, FONT_SIZE, color);
        tf.textColor  = color;
        tf.selectable = true;
        tf.multiline  = false;
        tf.wordWrap   = false;
        tf.text       = line;
        tf.width      = _w - PADDING * 2 - 8;
        tf.height     = LINE_H + 4;

        var y = _rows.length * (LINE_H + 2);
        tf.y = y;
        _content.addChild(tf);
        _rows.push(tf);
    }

    function _clearRows():Void {
        while (_content.numChildren > 0) _content.removeChildAt(0);
        _rows = [];
        _scrollY = 0;
        _updateScroll();
    }

    function _relayoutRows():Void {
        var w = _w - PADDING * 2 - 8;
        for (i in 0..._rows.length) {
            _rows[i].y     = i * (LINE_H + 2);
            _rows[i].width = w;
        }
        _updateScroll();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Scroll
    // ─────────────────────────────────────────────────────────────────────────

    function _scrollToBottom():Void {
        var maxScroll = Math.max(0, _content.height - (_h - BTN_H - PADDING * 2));
        _scrollY = maxScroll;
        _updateScroll();
    }

    function _updateScroll():Void {
        var viewH   = _h - BTN_H - PADDING * 2;
        var maxScroll = Math.max(0, _content.height - viewH);
        if (_scrollY < 0) _scrollY = 0;
        if (_scrollY > maxScroll) _scrollY = maxScroll;
        _content.y = -_scrollY;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Eventos
    // ─────────────────────────────────────────────────────────────────────────

    function _onWheel(e:MouseEvent):Void {
        _scrollY -= e.delta * 20;
        _updateScroll();
    }

    function _onDown(e:MouseEvent):Void {
        _pressing = true;
        _dragY0   = e.stageY;
        _scrollY0 = _scrollY;
    }

    function _onMove(e:MouseEvent):Void {
        if (!_pressing) return;
        _scrollY = _scrollY0 - (e.stageY - _dragY0);
        _updateScroll();
    }

    function _onUp(_:MouseEvent):Void {
        _pressing = false;
    }
}
