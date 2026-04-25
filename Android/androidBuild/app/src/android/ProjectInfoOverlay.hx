package android;

import android.AppConfig.ProjectInfoData;
import android.AppConfig.ProjectInfoEntryData;
import android.UiComponents.CardSection;
import android.UiComponents.UiButton;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.net.URLRequest;

class ProjectInfoOverlay extends Sprite {
    public var onStatus:String->Int->Void = null;

    var projectInfo:ProjectInfoData;

    var scrim:Shape;
    var card:CardSection;
    var introField:RichTextBlock;
    var projectField:RichTextBlock;
    var teamList:Sprite;
    var extraField:RichTextBlock;
    var linkButton:UiButton;
    var closeButton:UiButton;
    var openState:Bool = false;

    static inline var COLLAB_IMG_MAX:Float = 300;
    static inline var COLLAB_IMG_SIZE:Float = 80;
    static inline var COLLAB_ROW_H:Float   = 90;

    public function new(projectInfo:ProjectInfoData) {
        super();
        this.projectInfo = projectInfo;
        visible = false;
        build();
    }

    public function isOpen():Bool {
        return openState;
    }

    public function toggle(?force:Bool):Void {
        openState = force == null ? !openState : force;
        visible = openState;

        if (openState) {
            if (parent != null) parent.setChildIndex(this, parent.numChildren - 1);
            refreshText();
            card.content.y = 0;
        }
    }

    public function layoutOverlay(width:Float, height:Float, margin:Float):Void {
        visible = openState;

        scrim.graphics.clear();
        scrim.graphics.beginFill(0x020617, openState ? 0.80 : 0.0);
        scrim.graphics.drawRect(0, 0, width, height);
        scrim.graphics.endFill();

        var panelW = Math.min(580.0, width - margin * 2);
        var panelH = Math.min(height - margin * 2, height - margin * 2);

        card.setSize(panelW, panelH);
        card.x = (width - panelW) * 0.5;
        card.y = margin;

        var cw = card.innerWidth;
        var y  = 0.0;

        introField.x = 0;
        introField.y = y;
        introField.setWidth(cw);
        y += Math.max(52.0, introField.getContentHeight()) + 10;

        projectField.x = 0;
        projectField.y = y;
        projectField.setWidth(cw);
        y += Math.max(32.0, projectField.getContentHeight()) + 12;

        teamList.x = 0;
        teamList.y = y;
        y += rebuildTeamList(cw) + 12;

        extraField.x = 0;
        extraField.y = y;
        extraField.setWidth(cw);
        y += Math.max(36.0, extraField.getContentHeight()) + 12;

        var buttonGap = 12.0;
        var buttonW   = (cw - buttonGap) * 0.5;

        linkButton.x = 0;
        linkButton.y = y;
        linkButton.setSize(buttonW, 46);

        closeButton.x = buttonW + buttonGap;
        closeButton.y = y;
        closeButton.setSize(buttonW, 46);
    }

    function build():Void {
        scrim = new Shape();
        addChild(scrim);
        scrim.addEventListener(openfl.events.MouseEvent.CLICK, function(_) { toggle(false); });

        card = new CardSection(projectInfo.panelTitle);
        addChild(card);

        introField = createField(16, 0xE2E8F0, false);
        projectField = createField(13, 0x93C5FD, false);
        teamList = new Sprite();
        extraField = createField(12, 0x94A3B8, false);

        linkButton = new UiButton(projectInfo.linkLabel, 0x0EA5E9);
        closeButton = new UiButton("Cerrar", 0x334155);

        card.content.addChild(introField);
        card.content.addChild(projectField);
        card.content.addChild(teamList);
        card.content.addChild(extraField);
        card.content.addChild(linkButton);
        card.content.addChild(closeButton);

        linkButton.addEventListener(openfl.events.MouseEvent.CLICK, function(_) { openProjectLink(); });
        closeButton.addEventListener(openfl.events.MouseEvent.CLICK, function(_) { toggle(false); });

        refreshText();
    }

    function createField(size:Int, color:Int, bold:Bool):RichTextBlock {
        var field = new RichTextBlock(size, color, bold);
        return field;
    }

    function refreshText():Void {
        introField.setMarkupText(projectInfo.projectName + "\n" + projectInfo.overviewLines.join("\n"));
        projectField.setMarkupText("[b]Descarga del proyecto[/b]\n[color=#93C5FD]" + projectInfo.projectUrl + "[/color]");
        extraField.setMarkupText(projectInfo.extraLines.join("\n"));
    }

    function rebuildTeamList(width:Float):Float {
        while (teamList.numChildren > 0) teamList.removeChildAt(0);
        if (projectInfo == null || projectInfo.teamEntries == null || projectInfo.teamEntries.length == 0) return 0;

        var y = 0.0;
        var gap = 10.0;
        for (entry in projectInfo.teamEntries) {
            var row = makeCollabRow(entry, width);
            row.y = y;
            teamList.addChild(row);
            y += row.height + gap;
        }
        return y > 0 ? y - gap : 0;
    }

    function makeCollabRow(entry:ProjectInfoEntryData, width:Float):Sprite {
        var row = new Sprite();
        if (entry == null) return row;

        var bg = new Shape();
        bg.graphics.beginFill(0x111827, 0.7);
        bg.graphics.drawRoundRect(0, 0, width, COLLAB_ROW_H, 12, 12);
        bg.graphics.endFill();
        row.addChild(bg);

        var iconPath = entry.icon != null ? StringTools.trim(entry.icon) : "";
        var imgX = 10.0;
        var imgLoaded = false;
        var textX = imgX + COLLAB_IMG_SIZE + 14;
        var textW = width - textX - 10;
        var textBlock = new RichTextBlock(15, 0xF8FAFC, false);
        textBlock.x = textX;
        textBlock.y = 12;
        textBlock.setWidth(textW);
        textBlock.setMarkupText(entry.text);
        var rowHeight = Math.max(COLLAB_ROW_H, textBlock.getContentHeight() + 24);

        if (iconPath != "") {
            var chosen = pickRandomImage(iconPath);
            if (chosen != null) {
                try {
                    var bmd = Assets.getBitmapData(chosen);
                    if (bmd != null) {
                        var scale = Math.min(COLLAB_IMG_MAX / bmd.width, COLLAB_IMG_MAX / bmd.height);
                        scale = Math.min(scale, COLLAB_IMG_SIZE / bmd.width);
                        scale = Math.min(scale, COLLAB_IMG_SIZE / bmd.height);
                        scale = Math.min(scale, 1.0);

                        var bm = new Bitmap(bmd);
                        bm.smoothing = true;
                        bm.scaleX = scale;
                        bm.scaleY = scale;
                        bm.x = imgX + (COLLAB_IMG_SIZE - bm.width) * 0.5;
                        bm.y = (rowHeight - bm.height) * 0.5;
                        row.addChild(bm);
                        imgLoaded = true;
                    }
                } catch (_:Dynamic) {}
            }
        }

        if (!imgLoaded) {
            var ph = new Shape();
            ph.graphics.beginFill(0x1E293B);
            ph.graphics.drawRoundRect(imgX, (rowHeight - COLLAB_IMG_SIZE) * 0.5, COLLAB_IMG_SIZE, COLLAB_IMG_SIZE, 8, 8);
            ph.graphics.endFill();
            row.addChild(ph);
        }

        bg.graphics.clear();
        bg.graphics.beginFill(0x111827, 0.7);
        bg.graphics.drawRoundRect(0, 0, width, rowHeight, 12, 12);
        bg.graphics.endFill();
        row.addChild(textBlock);

        return row;
    }

    function pickRandomImage(folderPath:String):String {
        var exts = ["png", "jpg", "jpeg", "gif"];
        var prefix = StringTools.startsWith(folderPath, "assets/") ? folderPath.substr("assets/".length) : folderPath;
        if (!StringTools.endsWith(prefix, "/")) prefix += "/";

        var results:Array<String> = [];
        try {
            for (assetPath in lime.utils.Assets.list()) {
                if (!StringTools.startsWith(assetPath, prefix)) continue;
                var ext = haxe.io.Path.extension(assetPath).toLowerCase();
                if (exts.indexOf(ext) >= 0) results.push(assetPath);
            }
        } catch (_:Dynamic) {}

        if (results.length == 0) return null;
        return results[Std.random(results.length)];
    }

    function openProjectLink():Void {
        if (projectInfo == null || StringTools.trim(projectInfo.projectUrl) == "") {
            AppLogger.warn("No hay link configurado para el proyecto.");
            notifyStatus("Sin link configurado", 0x7C2D12);
            return;
        }

        try {
            Lib.getURL(new URLRequest(projectInfo.projectUrl), "_blank");
            AppLogger.log("Abriendo proyecto: " + projectInfo.projectUrl);
        } catch (error:Dynamic) {
            AppLogger.err("No pude abrir el link: " + Std.string(error));
            notifyStatus("No pude abrir el link", 0x7C2D12);
        }
    }

    function notifyStatus(text:String, color:Int):Void {
        if (onStatus != null) onStatus(text, color);
    }
}
