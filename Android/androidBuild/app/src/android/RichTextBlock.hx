package android;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

private typedef RichStyle = {
    var bold:Bool;
    var strike:Bool;
    var color:Int;
}

private typedef RichSegment = {
    var text:String;
    var bold:Bool;
    var strike:Bool;
    var color:Int;
}

class RichTextBlock extends Sprite {
    var baseSize:Int;
    var baseColor:Int;
    var baseBold:Bool;
    var maxWidth:Float = 100;
    var contentHeight:Float = 0;
    var markupText:String = "";

    public function new(size:Int, color:Int, ?bold:Bool = false) {
        super();
        baseSize = size;
        baseColor = color;
        baseBold = bold;
    }

    public function setWidth(value:Float):Void {
        if (value <= 0) value = 1;
        if (maxWidth == value) return;
        maxWidth = value;
        render();
    }

    public function setMarkupText(value:String):Void {
        markupText = value == null ? "" : value;
        render();
    }

    public function getContentHeight():Float {
        return contentHeight;
    }

    function render():Void {
        while (numChildren > 0) removeChildAt(0);

        var segments = parseMarkup(markupText);
        var x = 0.0;
        var y = 0.0;
        var lineHeight = measureLineHeight();

        for (segment in segments) {
            for (token in tokenize(segment.text)) {
                if (token == "\n") {
                    x = 0;
                    y += lineHeight;
                    lineHeight = measureLineHeight();
                    continue;
                }

                if (token == "" || (x == 0 && isWhitespace(token))) continue;

                var field = createField(token, segment.bold, segment.color);
                var tokenWidth = field.width;
                var tokenHeight = Math.max(measureLineHeight(segment.bold), field.height);

                if (!isWhitespace(token) && x > 0 && x + tokenWidth > maxWidth) {
                    x = 0;
                    y += lineHeight;
                    lineHeight = measureLineHeight(segment.bold);
                    if (isWhitespace(token)) continue;
                }

                field.x = x;
                field.y = y;
                addChild(field);

                if (segment.strike && !isWhitespace(token)) {
                    var strike = new Shape();
                    strike.graphics.lineStyle(Math.max(1, baseSize / 10), segment.color, 0.95);
                    var strikeY = field.y + Math.max(6.0, field.height * 0.48);
                    strike.graphics.moveTo(field.x, strikeY);
                    strike.graphics.lineTo(field.x + tokenWidth, strikeY);
                    addChild(strike);
                }

                x += tokenWidth;
                if (tokenHeight > lineHeight) lineHeight = tokenHeight;
            }
        }

        contentHeight = y + lineHeight;
    }

    function createField(text:String, bold:Bool, color:Int):TextField {
        var field = new TextField();
        field.embedFonts = true;
        field.selectable = false;
        field.mouseEnabled = false;
        field.autoSize = TextFieldAutoSize.LEFT;
        field.defaultTextFormat = new TextFormat(AppFonts.getUiFontName(bold), baseSize, color, bold);
        field.textColor = color;
        field.text = text;
        field.setTextFormat(new TextFormat(AppFonts.getUiFontName(bold), baseSize, color, bold));
        return field;
    }

    function measureLineHeight(?bold:Bool = false):Float {
        var field = createField("Ag", bold, baseColor);
        return Math.max(field.height, field.textHeight + 8);
    }

    function tokenize(text:String):Array<String> {
        var out:Array<String> = [];
        var current = "";
        var mode = 0; // 0 text, 1 spaces

        for (i in 0...text.length) {
            var ch = text.charAt(i);
            if (ch == "\n") {
                if (current != "") out.push(current);
                out.push("\n");
                current = "";
                mode = 0;
                continue;
            }

            var isSpace = (ch == " " || ch == "\t");
            if (current == "") {
                current = ch;
                mode = isSpace ? 1 : 0;
                continue;
            }

            if ((isSpace && mode == 1) || (!isSpace && mode == 0)) {
                current += ch;
            } else {
                out.push(current);
                current = ch;
                mode = isSpace ? 1 : 0;
            }
        }

        if (current != "") out.push(current);
        return out;
    }

    function isWhitespace(token:String):Bool {
        return StringTools.trim(token) == "";
    }

    function parseMarkup(raw:String):Array<RichSegment> {
        var text = normalizeMarkers(raw == null ? "" : raw);
        var out:Array<RichSegment> = [];
        var stack:Array<RichStyle> = [{ bold: baseBold, strike: false, color: baseColor }];
        var buffer = "";
        var i = 0;

        while (i < text.length) {
            if (startsWith(text, i, "[b]")) {
                flushBuffer(out, buffer, stack[stack.length - 1]);
                buffer = "";
                var top = stack[stack.length - 1];
                stack.push({ bold: true, strike: top.strike, color: top.color });
                i += 3;
                continue;
            }
            if (startsWith(text, i, "[/b]")) {
                flushBuffer(out, buffer, stack[stack.length - 1]);
                buffer = "";
                if (stack.length > 1) stack.pop();
                i += 4;
                continue;
            }
            if (startsWith(text, i, "[s]")) {
                flushBuffer(out, buffer, stack[stack.length - 1]);
                buffer = "";
                var topStrike = stack[stack.length - 1];
                stack.push({ bold: topStrike.bold, strike: true, color: topStrike.color });
                i += 3;
                continue;
            }
            if (startsWith(text, i, "[/s]")) {
                flushBuffer(out, buffer, stack[stack.length - 1]);
                buffer = "";
                if (stack.length > 1) stack.pop();
                i += 4;
                continue;
            }
            if (startsWith(text, i, "[color=")) {
                var close = text.indexOf("]", i);
                if (close > i) {
                    var colorSpec = text.substring(i + 7, close);
                    var parsed = parseColor(colorSpec, stack[stack.length - 1].color);
                    flushBuffer(out, buffer, stack[stack.length - 1]);
                    buffer = "";
                    var topColor = stack[stack.length - 1];
                    stack.push({ bold: topColor.bold, strike: topColor.strike, color: parsed });
                    i = close + 1;
                    continue;
                }
            }
            if (startsWith(text, i, "[/color]")) {
                flushBuffer(out, buffer, stack[stack.length - 1]);
                buffer = "";
                if (stack.length > 1) stack.pop();
                i += 8;
                continue;
            }

            buffer += text.charAt(i);
            i++;
        }

        flushBuffer(out, buffer, stack[stack.length - 1]);
        return mergeSegments(out);
    }

    function flushBuffer(out:Array<RichSegment>, buffer:String, style:RichStyle):Void {
        if (buffer == null || buffer == "") return;
        out.push({
            text: buffer,
            bold: style.bold,
            strike: style.strike,
            color: style.color
        });
    }

    function mergeSegments(segments:Array<RichSegment>):Array<RichSegment> {
        var out:Array<RichSegment> = [];
        for (segment in segments) {
            if (segment.text == "") continue;
            if (out.length > 0) {
                var last = out[out.length - 1];
                if (last.bold == segment.bold && last.strike == segment.strike && last.color == segment.color) {
                    last.text += segment.text;
                    continue;
                }
            }
            out.push({
                text: segment.text,
                bold: segment.bold,
                strike: segment.strike,
                color: segment.color
            });
        }
        return out;
    }

    function normalizeMarkers(text:String):String {
        var normalized = convertPairMarker(text, "**", "[b]", "[/b]");
        normalized = convertPairMarker(normalized, "~~", "[s]", "[/s]");
        return normalized;
    }

    function convertPairMarker(text:String, marker:String, openTag:String, closeTag:String):String {
        var out = new StringBuf();
        var i = 0;
        var open = true;

        while (i < text.length) {
            if (startsWith(text, i, marker)) {
                out.add(open ? openTag : closeTag);
                open = !open;
                i += marker.length;
            } else {
                out.add(text.charAt(i));
                i++;
            }
        }

        return out.toString();
    }

    function parseColor(value:String, fallback:Int):Int {
        if (value == null) return fallback;
        var clean = StringTools.trim(value);
        if (StringTools.startsWith(clean, "#")) clean = "0x" + clean.substr(1);
        try {
            return Std.parseInt(clean);
        } catch (_:Dynamic) {}
        return fallback;
    }

    function startsWith(text:String, index:Int, value:String):Bool {
        if (index + value.length > text.length) return false;
        return text.substr(index, value.length) == value;
    }
}
