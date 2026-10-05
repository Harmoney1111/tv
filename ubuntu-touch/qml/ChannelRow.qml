import QtQuick 2.12
import Lomiri.Components 1.3

// One channel in a list: logo, name, category, and a star that saves it.
// While picking the channel for ad breaks, a tick marks the current one instead.
ListItem {
    id: row
    property var channel
    property bool picking: false
    readonly property bool saved: root.savedIds[channel.id] === true
    readonly property bool chosen: picking && root.breakChannel !== null && root.breakChannel.id === channel.id
    signal watch()

    height: units.gu(8)
    onClicked: watch()

    Rectangle {
        id: logoBox
        anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
        width: units.gu(10)
        height: units.gu(6)
        radius: units.gu(1)
        color: "#1C1838"

        Image {
            id: logo
            anchors { fill: parent; margins: units.gu(0.5) }
            source: row.channel.logo
            sourceSize.height: units.gu(6)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Label {
            anchors.centerIn: parent
            visible: logo.status !== Image.Ready
            text: row.channel.name.charAt(0)
            textSize: Label.Large
            color: "#7A2BFF"
        }
    }

    Column {
        anchors {
            left: logoBox.right; leftMargin: units.gu(2)
            right: star.left; rightMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }
        Label {
            width: parent.width
            text: row.channel.name
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: row.channel.group
            textSize: Label.Small
            color: theme.palette.normal.backgroundSecondaryText
            elide: Text.ElideRight
        }
    }

    AbstractButton {
        id: star
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: units.gu(7)
        enabled: !row.picking
        opacity: row.picking ? 0 : 1
        onClicked: root.toggleSaved(row.channel)

        Icon {
            anchors.centerIn: parent
            width: units.gu(3)
            height: width
            name: row.saved ? "starred" : "non-starred"
            color: row.saved ? root.accent : theme.palette.normal.baseText
        }
    }

    Icon {
        anchors.centerIn: star
        width: units.gu(3)
        height: width
        visible: row.chosen
        name: "tick"
        color: root.accent
    }
}
