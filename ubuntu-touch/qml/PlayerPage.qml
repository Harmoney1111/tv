import QtQuick 2.12
import QtQuick.Window 2.2
import QtMultimedia 5.12
import QtSystemInfo 5.0
import Lomiri.Components 1.3

// Full screen video. Tap to show or hide the controls; swipe left or right to change channel.
//
// Ad skip: while a channel plays, AdWatcher reads its playlist for ad breaks. During a
// break the chosen break channel stands in, and the channel comes back when the break ends.
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

    header: Item {}

    onPlayingChanged: if (playing) hideTimer.restart()

    onFailedChanged: {
        // The break channel let us down: go back to the show and sit this break out.
        if (failed && onBreak) {
            console.log("Revell T.V: break channel failed");
            leaveBreak(true);
        }
    }

    onWatchingForAdsChanged: if (!watchingForAds) leaveBreak(false)

    function change(step) {
        onBreak = false;
        breakHold = false;
        index = (index + step + channels.length) % channels.length;
        showControls(true);
        video.play();
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
        source: page.onBreak && page.breakChannel ? page.breakChannel.url : (page.channel ? page.channel.url : "")
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
        running: !page.playing && !page.failed
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - units.gu(8), units.gu(50))
        spacing: units.gu(2)
        visible: page.failed || (page.slow && !page.playing)

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
        id: slowTimer
        interval: 20000
        running: true
        onTriggered: page.slow = true
    }

    AdWatcher {
        id: adWatcher
        url: page.watchingForAds ? page.channel.url : ""
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

    // The page is not in the window yet while it is being made, so go full screen just after.
    Component.onCompleted: Qt.callLater(function () {
        if (page.Window.window) {
            page.Window.window.visibility = Window.FullScreen;
        }
    })

    Component.onDestruction: {
        screenSaver.screenSaverEnabled = true;
        if (page.Window.window) {
            page.Window.window.visibility = Window.AutomaticVisibility;
        }
    }
}
