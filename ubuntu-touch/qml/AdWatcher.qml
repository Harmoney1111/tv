import QtQuick 2.12
import "adwatch.js" as AdWatch
import "pluto.js" as Pluto

// Re-reads the playlist of the channel being watched every 4 seconds and says whether
// the viewer is in an ad break now (nowAd) and still will be in a few seconds (soonAd).
// A new Pluto session opens with an ad bumper of its own, so nothing counts until the
// watcher has seen the programme once (armed).
//
// A Pluto channel gets a session of its own here, apart from the player's, because the
// player moves to the break channel while this keeps watching.
Item {
    id: watcher
    property string url: ""
    property string clientId: ""
    property int lagSegments: 3
    property bool armed: false
    property bool nowAd: false
    property bool soonAd: false
    property double lastReport: 0

    property string mediaUrl: ""
    property string sessionUrl: ""
    property double sessionAsked: 0
    property var request: null
    property double requestStarted: 0

    onUrlChanged: restart()

    function restart() {
        if (request) {
            request.abort();
            request = null;
        }
        armed = false;
        nowAd = false;
        soonAd = false;
        mediaUrl = "";
        sessionUrl = "";
        sessionAsked = 0;
        lastReport = 0;
        poll.running = url !== "";
        if (poll.running) {
            poll.restart();
        }
    }

    function fetch(address, done) {
        var forUrl = url;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (watcher.request === xhr) {
                watcher.request = null;
            }
            if (forUrl === watcher.url) {
                done(xhr.status === 200 ? xhr.responseText : "");
            }
        };
        request = xhr;
        requestStarted = Date.now();
        xhr.open("GET", address);
        xhr.send();
    }

    function step() {
        if (request) {
            if (Date.now() - requestStarted < 15000) {
                return;
            }
            request.abort();
            request = null;
        }
        if (mediaUrl !== "") {
            fetch(mediaUrl, report);
            return;
        }
        if (Pluto.channelId(url) !== "" && sessionUrl === "") {
            // Ask again if Pluto did not answer, or has not within 15 seconds.
            if (Date.now() - sessionAsked > 15000) {
                var forUrl = url;
                sessionAsked = Date.now();
                Pluto.openSession(url, clientId, function (session) {
                    if (forUrl === watcher.url) {
                        sessionUrl = session;
                        sessionAsked = session !== "" ? sessionAsked : 0;
                    }
                });
            }
            return;
        }
        var master = sessionUrl !== "" ? sessionUrl : url;
        fetch(master, function (text) {
            if (text === "") {
                return;
            }
            var variant = AdWatch.firstVariant(text, master);
            mediaUrl = variant !== "" ? variant : master;
            if (variant === "") {
                report(text);
            }
        });
    }

    function report(text) {
        var result = text !== "" ? AdWatch.analyse(text, lagSegments) : null;
        if (!result) {
            return;
        }
        lastReport = Date.now();
        if (!armed) {
            if (result.nowAd) {
                return;
            }
            armed = true;
            console.log("Revell T.V: watching for ad breaks on", url);
        }
        if (result.nowAd !== nowAd) {
            console.log("Revell T.V: playlist says", result.nowAd ? "ad break" : "programme");
        }
        nowAd = result.nowAd;
        soonAd = result.soonAd;
    }

    Timer {
        id: poll
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: watcher.step()
    }
}
