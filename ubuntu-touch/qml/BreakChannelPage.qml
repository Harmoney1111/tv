import QtQuick 2.12
import Lomiri.Components 1.3
import "channels.js" as Channels

// Picks the channel to watch during ad breaks: the music channels, or any channel by search.
Page {
    id: page
    readonly property bool searching: search.text.trim() !== ""
    readonly property var music: root.channels.filter(function (channel) { return channel.group === "Music"; })
    property var results: []

    header: PageHeader {
        id: header
        title: "Channel during ads"
    }

    TextField {
        id: search
        anchors { top: header.bottom; left: parent.left; right: parent.right; margins: units.gu(2) }
        placeholderText: "Search any channel"
        inputMethodHints: Qt.ImhNoPredictiveText
        primaryItem: Icon {
            width: units.gu(2)
            height: width
            name: "find"
        }
        onTextChanged: searchDelay.restart()
    }

    Timer {
        id: searchDelay
        interval: 250
        onTriggered: page.results = page.searching ? Channels.search(root.channels, search.text) : []
    }

    Label {
        id: hint
        anchors { top: search.bottom; left: parent.left; right: parent.right; margins: units.gu(2) }
        visible: !page.searching
        text: "Music channels"
        color: theme.palette.normal.backgroundSecondaryText
    }

    ListView {
        anchors {
            top: page.searching ? search.bottom : hint.bottom
            topMargin: units.gu(1)
            left: parent.left; right: parent.right; bottom: parent.bottom
        }
        clip: true
        model: page.searching ? page.results : page.music
        delegate: ChannelRow {
            channel: modelData
            picking: true
            onWatch: {
                root.setBreakChannel(modelData);
                stack.pop();
            }
        }
    }
}
