import QtQuick 2.12
import QtQuick.Window 2.2
import QtMultimedia 5.12
import QtSystemInfo 5.0
import Lomiri.Components 1.3
import "pluto.js" as Pluto
import "quality.js" as Quality

// Full screen video. Tap to show or hide the controls; swipe left or right to change channel.
//
// Ad skip: while a channel plays, AdWatcher reads its playlist for ad breaks. During a
// break the chosen break channel stands in, and the channel comes back when the break ends.
//
// Pluto TV channels need a Pluto session before they play (pluto.js).
//
// The phone's video decoder fails when a stream changes picture size, so a channel plays
// one variant of its stream (quality.js). When the decoder fails anyway the player still
// says it is playing, so a picture that stops moving gets the channel reopened.
Page {
    id: page
    property var channels: []
    property int index: 0
    readonly property var channel: channels[index]
    readonly property bool failed: video.error !== MediaPlayer.NoError || video.status === MediaPlayer.InvalidMedia
    // The phone's media service reports "playing" once the picture starts; it never
    // reports a buffered status, so that cannot be used here.
    readonly property bool playing: !failed && video.playbackState === MediaPlayer.PlayingState
    readonly property bool saved: channel !== undefined && root.savedIds[channel.id] === true
    property bool controlsShown: true
    property bool slow: false

    readonly property var breakChannel: root.breakChannel
    readonly property bool watchingForAds: root.adSkip && breakChannel !== null && channel !== undefined
                                           && channel.id !== breakChannel.id
    property bool onBreak: false     // the break channel is standing in for an ad break
    property bool breakHold: false   // stay on the channel for the rest of this break

    // The channel on screen (the break channel during a break) and the address it plays
    // from: the list's own, or for Pluto the one in a session opened for it.
    readonly property var screenChannel: onBreak && breakChannel ? breakChannel : (channel ? channel : null)
    property string address: ""
    property string master: ""       // the stream's own address, when a variant of it plays
    property int opening: 0          // counts sessions asked for, so a late answer is ignored
    property bool reachedPlaying: false   // the picture has moved (the player says "playing" before it does)
    property int reopened: 0         // times the channel was reopened since it last played a minute
    property int lastPosition: 0
    property int stillChecks: 0      // checks in a row that found the picture where it was
    // Where a playlist of the app's own goes (see playOwnPlaylist). The media service takes it
    // from the app's cache folder; writing it needs QML_XHR_ALLOW_FILE_WRITE=1, which
    // the .desktop file sets.
    readonly property string playlistFile: "file:///home/phablet/.cache/revell-tv.harmoney1111/channel.m3u8"

    header: Item {}

    onScreenChannelChanged: {
        reopened = 0;
        openScreenChannel();
    }

    function openScreenChannel() {
        var target = screenChannel;
        var ticket = ++opening;
        address = "";
        master = "";
        reachedPlaying = false;
        stillChecks = 0;
        lastPosition = 0;
        if (!target) {
            return;
        }
        if (Pluto.channelId(target.url) === "") {
            playSteady(target.url, ticket);
            return;
        }
        Pluto.openSession(target.url, root.plutoClient, function (session) {
            if (ticket !== opening) {
                return;
            }
            // Without a session the list's own address is tried, and fails like any dead channel.
            if (session === "") {
                console.log("Revell T.V: no Pluto session for", target.name);
            }
            playSteady(session !== "" ? session : target.url, ticket);
        });
    }

    // Plays one variant of the stream, or the stream itself when it has none to choose
    // from or its playlist does not answer.
    function playSteady(url, ticket) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || ticket !== opening) {
                return;
            }
            var choice = xhr.status === 200 ? Quality.steadyChoice(xhr.responseText, url) : null;
            if (choice && choice.playlist) {
                playOwnPlaylist(choice.playlist, url, ticket);
                return;
            }
            master = choice ? url : "";
            address = choice ? choice.url : url;
            video.play();
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Saves a playlist of one variant and its sound and plays it. If the file cannot be
    // written, the old one plays or nothing does, and the stream itself takes over.
    function playOwnPlaylist(text, url, ticket) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || ticket !== opening) {
                return;
            }
            master = url;
            address = playlistFile;
            video.play();
        };
        xhr.open("PUT", playlistFile);
        xhr.send(text);
    }

    onPlayingChanged: if (playing) hideTimer.restart()

    onFailedChanged: {
        // Without an address (while a channel opens) the player reports a missing file.
        if (!failed || address === "") {
            return;
        }
        // The break channel let us down: go back to the show and sit this break out.
        if (onBreak) {
            console.log("Revell T.V: break channel failed");
            leaveBreak(true);
            return;
        }
        if (!reachedPlaying && master !== "") {
            playMaster("the variant failed");
            return;
        }
        // It played and then stopped: open the channel again.
        if (reachedPlaying) {
            reopen("it stopped");
        }
    }

    // The chosen variant did not start (a playlist that sends players elsewhere can make
    // its variants' addresses wrong): play the stream itself.
    function playMaster(why) {
        console.log("Revell T.V: playing the whole stream of", screenChannel ? screenChannel.name : "", "because", why);
        address = master;
        master = "";
        stillChecks = 0;
        video.play();
    }

    // Opens the channel again, a few times at most until it has played a minute.
    function reopen(why) {
        if (reopened >= 5 || reopenTimer.running) {
            return;
        }
        reopened++;
        console.log("Revell T.V: reopening", screenChannel ? screenChannel.name : "", "because", why, "(" + reopened + ")");
        reopenTimer.restart();
    }

    onWatchingForAdsChanged: if (!watchingForAds) leaveBreak(false)

    function change(step) {
        onBreak = false;
        breakHold = false;
        index = (index + step + channels.length) % channels.length;
        showControls(true);
    }

    // The watcher changed its mind about whether the viewer is in a break.
    function adSignal() {
        if (!adWatcher.armed) {
            return;
        }
        if (onBreak) {
            if (!adWatcher.soonAd) {
                console.log("Revell T.V: break ending, back to", channel.name);
                leaveBreak(false);
            }
        } else if (adWatcher.nowAd) {
            enterBreak();
        } else {
            breakHold = false;
        }
    }

    function enterBreak() {
        if (onBreak || breakHold || !watchingForAds) {
            return;
        }
        console.log("Revell T.V: ad break on", channel.name, "- switching to", breakChannel.name);
        onBreak = true;
    }

    function leaveBreak(hold) {
        if (!onBreak) {
            return;
        }
        onBreak = false;
        // Never go back to the break channel for the same break: if the playlist says
        // its tail is still running, wait it out. The hold lifts when the show is back.
        breakHold = adWatcher.armed ? adWatcher.nowAd : hold;
    }

    function showControls(show) {
        controlsShown = show;
        if (show) {
            hideTimer.restart();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Video {
        id: video
        anchors.fill: parent
        autoPlay: true
        fillMode: VideoOutput.PreserveAspectFit
        source: page.address
        onSourceChanged: {
            page.slow = false;
            slowTimer.restart();
        }
        onPlaybackStateChanged: console.log("Revell T.V: playback state", playbackState, "status", status)
        onStatusChanged: console.log("Revell T.V: status", status)
        onErrorChanged: console.log("Revell T.V: error", error, errorString)
    }

    MouseArea {
        anchors.fill: parent
        property real startX: 0
        onPressed: startX = mouse.x
        onReleased: {
            var moved = mouse.x - startX;
            if (Math.abs(moved) > width / 4) {
                page.change(moved < 0 ? 1 : -1);
            } else {
                page.showControls(!page.controlsShown);
            }
        }
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: !page.playing && (!page.failed || reopenTimer.running)
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - units.gu(8), units.gu(50))
        spacing: units.gu(2)
        visible: (page.failed && !reopenTimer.running) || (page.slow && !page.playing)

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "white"
            text: page.failed ? "This channel is not working right now."
                              : "Still trying. This channel may be offline."
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Next channel"
            color: root.accent
            onClicked: page.change(1)
        }
    }

    // Controls: back, name and star at the top; previous and next at the bottom.
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: units.gu(9)
        visible: page.controlsShown
        gradient: Gradient {
            GradientStop { position: 0; color: "#CC000000" }
            GradientStop { position: 1; color: "transparent" }
        }

        AbstractButton {
            id: back
            anchors { left: parent.left; top: parent.top }
            width: units.gu(7)
            height: units.gu(7)
            onClicked: stack.pop()
            Icon { anchors.centerIn: parent; width: units.gu(3); height: width; name: "back"; color: "white" }
        }
        Label {
            anchors { left: back.right; right: star.left; verticalCenter: back.verticalCenter }
            text: page.channel ? page.channel.name : ""
            color: "white"
            textSize: Label.Large
            elide: Text.ElideRight
        }
        AbstractButton {
            id: star
            anchors { right: parent.right; top: parent.top }
            width: units.gu(7)
            height: units.gu(7)
            onClicked: { root.toggleSaved(page.channel); page.showControls(true); }
            Icon {
                anchors.centerIn: parent
                width: units.gu(3)
                height: width
                name: page.saved ? "starred" : "non-starred"
                color: page.saved ? root.accent : "white"
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: units.gu(10)
        visible: page.controlsShown && page.channels.length > 1
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#CC000000" }
        }

        AbstractButton {
            anchors { left: parent.left; bottom: parent.bottom }
            width: units.gu(9)
            height: units.gu(8)
            onClicked: page.change(-1)
            Icon { anchors.centerIn: parent; width: units.gu(4); height: width; name: "media-skip-backward"; color: "white" }
        }
        Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: units.gu(3) }
            text: (page.index + 1) + " of " + page.channels.length
            color: "white"
        }
        AbstractButton {
            anchors { right: parent.right; bottom: parent.bottom }
            width: units.gu(9)
            height: units.gu(8)
            onClicked: page.change(1)
            Icon { anchors.centerIn: parent; width: units.gu(4); height: width; name: "media-skip-forward"; color: "white" }
        }
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: if (page.playing) page.controlsShown = false
    }

    Timer {
        id: reopenTimer
        interval: 1000
        onTriggered: page.openScreenChannel()
    }

    // The player's position tells whether the picture moves. The decoder failing leaves
    // the player "playing" with its position stuck or below zero; nine seconds without the
    // picture moving count as stopped. A variant that never moves gives way to the stream.
    Timer {
        interval: 3000
        repeat: true
        running: page.playing && page.address !== "" && !reopenTimer.running
        onTriggered: {
            var position = video.position;
            if (position > 0 && position !== page.lastPosition) {
                page.reachedPlaying = true;
                page.stillChecks = 0;
            } else {
                page.stillChecks++;
            }
            page.lastPosition = position;
            if (page.stillChecks >= 3) {
                page.stillChecks = 0;
                if (!page.reachedPlaying && page.master !== "") {
                    page.playMaster("the variant did not start");
                } else if (page.reachedPlaying) {
                    page.reopen("the picture stopped");
                }
            }
        }
    }

    // A minute of playing, with the picture moving, clears the count of reopenings.
    Timer {
        interval: 60000
        running: page.playing
        onTriggered: if (page.stillChecks === 0 && video.position > 0) page.reopened = 0
    }

    Timer {
        id: slowTimer
        interval: 20000
        running: true
        onTriggered: page.slow = true
    }

    AdWatcher {
        id: adWatcher
        url: page.watchingForAds ? page.channel.url : ""
        clientId: root.plutoClient
        onNowAdChanged: page.adSignal()
        onSoonAdChanged: page.adSignal()
    }

    // If the playlist stops answering during a break, go back rather than stay away.
    Timer {
        interval: 5000
        repeat: true
        running: page.onBreak
        onTriggered: {
            if (Date.now() - adWatcher.lastReport > 30000) {
                console.log("Revell T.V: playlist went quiet during the break");
                page.leaveBreak(false);
            }
        }
    }

    // Shown for the whole break, above the controls.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: units.gu(10) }
        height: breakRow.height + units.gu(2)
        visible: page.onBreak
        color: "#E60A081C"

        Row {
            id: breakRow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(2) }
            spacing: units.gu(2)

            Label {
                width: parent.width - backNow.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                color: "white"
                text: page.onBreak && page.breakChannel ? "Ad break on " + page.channel.name + ". Watching "
                                     + page.breakChannel.name + " until it is over." : ""
            }
            Button {
                id: backNow
                anchors.verticalCenter: parent.verticalCenter
                text: "Back now"
                color: root.accent
                onClicked: page.leaveBreak(true)
            }
        }
    }

    ScreenSaver {
        id: screenSaver
        screenSaverEnabled: false
    }

    Component.onCompleted: {
        openScreenChannel();
        // The page is not in the window yet while it is being made, so go full screen just after.
        Qt.callLater(function () {
            if (page.Window.window) {
                page.Window.window.visibility = Window.FullScreen;
            }
        });
    }

    Component.onDestruction: {
        screenSaver.screenSaverEnabled = true;
        if (page.Window.window) {
            page.Window.window.visibility = Window.AutomaticVisibility;
        }
    }
}
