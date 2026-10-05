import QtQuick 2.12
import Lomiri.Components 1.3

// The channels of one section. The Saved section follows the stars as they change.
Page {
    id: page
    property var channels: []
    property bool savedList: false
    readonly property var shown: savedList ? root.savedChannels : channels

    header: PageHeader {
        id: header
        title: page.title
    }

    ListView {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: page.shown
        delegate: ChannelRow {
            channel: modelData
            onWatch: root.watch(page.shown, index)
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - units.gu(8)
        visible: page.shown.length === 0
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        text: page.savedList ? "Tap the star next to a channel to save it here." : "No channels here."
    }
}
