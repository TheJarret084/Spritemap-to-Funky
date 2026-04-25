package android.api;

import android.AppConfig;
import openfl.display.Application;

#if (cpp && !android)
import cpp.RawConstPointer;
import cpp.RawPointer;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
#end

class DiscordRpcService {
    public var enabled(default, null):Bool = false;

    var host:Application;

    #if (cpp && !android)
    var handlers:DiscordEventHandlers;
    var presence:DiscordRichPresence;
    #end

    public function new(host:Application) {
        this.host = host;
    }

    public function init():Void {
        #if (cpp && !android)
        var appId = StringTools.trim(AppConfig.DISCORD_APP_ID);
        if (appId == "") {
            trace("Discord RPC desactivado: falta AppConfig.DISCORD_APP_ID.");
            return;
        }

        handlers = new DiscordEventHandlers();
        Discord.Initialize(appId, RawPointer.addressOf(handlers), false, null);

        presence = new DiscordRichPresence();
        presence.type = DiscordActivityType_Playing;
        presence.details = AppConfig.DISCORD_DEFAULT_DETAILS;
        presence.state = AppConfig.DISCORD_DEFAULT_STATE;
        presence.largeImageKey = emptyToNull(AppConfig.DISCORD_LARGE_IMAGE_KEY);
        presence.largeImageText = emptyToNull(AppConfig.DISCORD_LARGE_IMAGE_TEXT);
        presence.smallImageKey = emptyToNull(AppConfig.DISCORD_SMALL_IMAGE_KEY);
        presence.smallImageText = emptyToNull(AppConfig.DISCORD_SMALL_IMAGE_TEXT);
        presence.startTimestamp = cast Std.int(Date.now().getTime() / 1000);

        Discord.UpdatePresence(RawConstPointer.addressOf(presence));
        host.onUpdate.add(onUpdate);
        host.onExit.add(onExit);
        enabled = true;
        trace("Discord RPC inicializado para desktop.");
        #end
    }

    public function setPresence(details:String, state:String):Void {
        #if (cpp && !android)
        if (!enabled || presence == null) return;

        presence.details = emptyToNull(details);
        presence.state = emptyToNull(state);
        Discord.UpdatePresence(RawConstPointer.addressOf(presence));
        #end
    }

    #if (cpp && !android)
    function onUpdate(_deltaTime:Int):Void {
        if (!enabled) return;
        Discord.RunCallbacks();
    }

    function onExit(_exitCode:Int):Void {
        shutdown();
    }

    function shutdown():Void {
        if (!enabled) return;
        enabled = false;
        host.onUpdate.remove(onUpdate);
        host.onExit.remove(onExit);
        Discord.ClearPresence();
        Discord.Shutdown();
    }

    inline function emptyToNull(value:String):String {
        if (value == null) return null;
        var trimmed = StringTools.trim(value);
        return trimmed == "" ? null : trimmed;
    }
    #end
}
