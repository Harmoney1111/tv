import QtQuick 2.12
import Lomiri.Components 1.3
import "channels.js" as Channels

// A search box, then the sections: Saved, Popular, All channels and the categories.
Page {
    id: page
    readonly property bool searching: search.text.trim() !== ""
    readonly property var sections: root.listState === "ready" ? Channels.sections(root.channels, root.savedChannels) : []
    property var results: []

    header: PageHeader {
        id: header
        contents: Image {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: units.gu(3.5)
            fillMode: Image.PreserveAspectFit
            source: "../assets/logo.png"
        }
        trailingActionBar.actions: [
            Action {
                iconName: "settings"
                text: "Ad skip"
                onTriggered: root.openAdSkip()
            },
            Action {
                iconName: "reload"
                text: "Reload the channel list"
                onTriggered: root.load()
            }
        ]
    }

    TextField {
        id: search
        anchors { top: header.bottom; left: parent.left; right: parent.right; margins: units.gu(2) }
        placeholderText: "Search, for example news"
        inputMethodHints: Qt.ImhNoPredictiveText
        enabled: root.listState === "ready"
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

    ListView {
        anchors { top: search.bottom; topMargin: units.gu(1); left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        visible: !page.searching
        model: page.sections
        delegate: ListItem {
            height: layout.height + (divider.visible ? divider.height : 0)
            onClicked: root.openChannels(modelData.name, modelData.channels)

            ListItemLayout {
                id: layout
                title.text: modelData.name
                title.font.weight: index < 3 ? Font.DemiBold : Font.Normal

                Label {
                    SlotsLayout.position: SlotsLayout.Trailing
                    text: modelData.channels.length
                    color: theme.palette.normal.backgroundSecondaryText
                }
                ProgressionSlot {}
            }
        }
    }

    ListView {
        anchors { top: search.bottom; topMargin: units.gu(1); left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        visible: page.searching
        model: page.results
        delegate: ChannelRow {
            channel: modelData
            onWatch: root.watch(page.results, index)
        }

        Label {
            anchors.centerIn: parent
            visible: page.searching && page.results.length === 0 && !searchDelay.running
            text: "No channels match"
        }
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: root.listState === "loading"
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - units.gu(8)
        spacing: units.gu(2)
        visible: root.listState === "failed"

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "The channel list could not be loaded. Check the internet connection and try again."
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Try again"
            color: root.accent
            onClicked: root.load()
        }
    }
}
