package android;

import openfl.display.DisplayObject;
import openfl.display.InteractiveObject;
import openfl.display.Stage;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.geom.Point;

/**
 * Mouse virtual armado a mano a partir de TouchEvent reales.
 *
 * Por qué existe: toda la UI (UiButton, ProjectNavbar, ConsoleView,
 * ToolTabButton, AnimationListView, el botón de "explorar" de UiInput)
 * escucha MouseEvent directamente, y algunas cosas escuchan MouseEvent a
 * nivel `stage` para poder arrastrar más allá de sus propios límites
 * (scroll de la consola y de la lista de animaciones). En vez de depender
 * de que Lime "adivine" bien cuándo convertir el touch en mouse (que es
 * justo lo que fallaba en el dispositivo), acá tomamos control manual:
 * escuchamos los toques crudos y nosotros mismos generamos los MouseEvent
 * que el resto de la UI ya sabe manejar.
 *
 * Comportamiento pedido:
 *  - Al tocar                  -> MOUSE_DOWN sobre lo que hay debajo del dedo.
 *  - Mientras se mantiene y se
 *    mueve el dedo             -> MOUSE_MOVE (arrastre), tanto en el objeto
 *                                 tocado como en el stage, para que las
 *                                 listas con scroll lo detecten aunque el
 *                                 dedo se salga de sus límites.
 *  - Al soltar                 -> MOUSE_UP + CLICK en el punto donde el dedo
 *                                 se LEVANTA (no en el punto donde arrancó
 *                                 el toque).
 *
 * Requiere que Multitouch.inputMode esté en TOUCH_POINT (ver AndroidApp.hx),
 * así Lime nos manda TouchEvent reales y no compite simulando su propio
 * MouseEvent por su cuenta (eso duplicaría clicks).
 */
class VirtualMouse {
    // Si algún día dos elementos interactivos se superponen en el mismo punto
    // (ej. un fondo oscuro detrás de un panel) y responde el de atrás en vez
    // del de adelante, probá invertir este flag.
    static inline var TOPMOST_FIRST:Bool = true;

    var stage:Stage;
    var activeTouchId:Int = -1;
    var pressedTarget:InteractiveObject;

    public function new(stage:Stage) {
        this.stage = stage;
        stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 0, true);
        stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 0, true);
        stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 0, true);
    }

    function onTouchBegin(event:TouchEvent):Void {
        // Un solo dedo a la vez; ignoramos toques adicionales mientras haya uno activo.
        if (activeTouchId != -1) return;
        activeTouchId = event.touchPointID;

        pressedTarget = hitTarget(event.stageX, event.stageY);
        dispatchAt(pressedTarget, MouseEvent.MOUSE_DOWN, event.stageX, event.stageY);
    }

    function onTouchMove(event:TouchEvent):Void {
        if (event.touchPointID != activeTouchId) return;

        // Al stage: para que los arrastres "globales" (scroll de la consola
        // y de la lista de animaciones) sigan recibiendo movimiento aunque
        // el dedo se salga del elemento original.
        dispatchAt(stage, MouseEvent.MOUSE_MOVE, event.stageX, event.stageY);

        if (pressedTarget != null && pressedTarget != stage) {
            dispatchAt(pressedTarget, MouseEvent.MOUSE_MOVE, event.stageX, event.stageY);
        }
    }

    function onTouchEnd(event:TouchEvent):Void {
        if (event.touchPointID != activeTouchId) return;
        activeTouchId = -1;

        dispatchAt(stage, MouseEvent.MOUSE_UP, event.stageX, event.stageY);
        if (pressedTarget != null && pressedTarget != stage) {
            dispatchAt(pressedTarget, MouseEvent.MOUSE_UP, event.stageX, event.stageY);
        }

        // El click se dispara donde el dedo se LEVANTA, no donde arrancó el toque.
        var releaseTarget = hitTarget(event.stageX, event.stageY);
        if (releaseTarget != null) {
            dispatchAt(releaseTarget, MouseEvent.CLICK, event.stageX, event.stageY);
        }

        pressedTarget = null;
    }

    function hitTarget(stageX:Float, stageY:Float):InteractiveObject {
        var objects = stage.getObjectsUnderPoint(new Point(stageX, stageY));
        var count = objects.length;

        var start = TOPMOST_FIRST ? 0 : count - 1;
        var stop  = TOPMOST_FIRST ? count : -1;
        var step  = TOPMOST_FIRST ? 1 : -1;

        var i = start;
        while (i != stop) {
            var current:DisplayObject = objects[i];
            while (current != null) {
                if (Std.isOfType(current, InteractiveObject)) {
                    var io:InteractiveObject = cast current;
                    if (io.mouseEnabled) return io;
                }
                current = current.parent;
            }
            i += step;
        }

        return stage;
    }

    function dispatchAt(target:InteractiveObject, type:String, stageX:Float, stageY:Float):Void {
        if (target == null) return;
        var local = (target == stage) ? new Point(stageX, stageY) : target.globalToLocal(new Point(stageX, stageY));
        target.dispatchEvent(new MouseEvent(type, true, false, local.x, local.y));
    }
}
