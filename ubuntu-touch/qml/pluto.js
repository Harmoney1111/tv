.pragma library

// Pluto TV channels, ported from the Roku app (Pluto.brs).
//
// The channel list gives them as jmp2.uk/plu-<id> addresses, which Pluto stopped
// serving in October 2026 ("channel not permitted for partner"). The app now opens a
// Pluto session itself, the way Pluto's own players do, and plays the address Pluto
// hands back for it. Every session is good for one channel at a time.

var BOOT = "https://boot.pluto.tv/v4/start?appName=web&appVersion=1.2.0&deviceType=web"
    + "&deviceMake=UbuntuTouch&deviceModel=web&deviceVersion=unknown&clientModelNumber=1.0.0"
    + "&serverSideAds=false&clientID=";

// The Pluto channel id in a jmp2.uk/plu-<id> address, or "" for any other channel.
function channelId(url) {
    var mark = url.indexOf("jmp2.uk/plu-");
    return mark < 0 ? "" : url.substring(mark + 12).split(".")[0];
}

// Opens a new Pluto session and calls done(address) with the channel's address in it,
// or done("") when Pluto does not answer.
function openSession(url, clientId, done) {
    var channel = channelId(url);
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        var boot = null;
        try {
            boot = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
        } catch (e) {
        }
        if (!boot || !boot.servers || !boot.servers.stitcher || !boot.stitcherParams || !boot.sessionToken) {
            done("");
            return;
        }
        done(boot.servers.stitcher + "/v2/stitch/hls/channel/" + channel + "/master.m3u8?"
             + boot.stitcherParams + "&jwt=" + boot.sessionToken + "&masterJWTPassthrough=true");
    };
    xhr.open("GET", BOOT + clientId);
    xhr.send();
}

// A random id that Pluto knows this phone by (kept in the settings).
function newClientId() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
        var r = Math.floor(Math.random() * 16);
        return (c === "x" ? r : (r & 3) | 8).toString(16);
    });
}
