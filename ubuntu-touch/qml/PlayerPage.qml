import QtQuick 2.12
import QtQuick.Window 2.2
import QtMultimedia 5.12
import QtSystemInfo 5.0
import Lomiri.Components 1.3

// Full screen video. Tap to show or hide the controls; swipe left or right to change channel.
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

    header: Item {}

    onPlayingChanged: if (playing) hideTimer.restart()

    function change(step) {
        index = (index + step + channels.length) % channels.length;
        slow = false;
        slowTimer.restart();
        showControls(true);
        video.play();
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
        source: page.channel ? page.channel.url : ""
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
