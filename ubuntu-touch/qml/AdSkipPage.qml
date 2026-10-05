import QtQuick 2.12
import Lomiri.Components 1.3

// Ad skip settings: on or off, and the channel to watch during ad breaks.
Page {
    id: page

    header: PageHeader {
        id: header
        title: "Ad skip"
    }

    Column {
        anchors { top: header.bottom; left: parent.left; right: parent.right }

        ListItem {
            height: switchLayout.height + (divider.visible ? divider.height : 0)

            ListItemLayout {
                id: switchLayout
                title.text: "Skip ad breaks"

                Switch {
                    SlotsLayout.position: SlotsLayout.Trailing
                    checked: root.adSkip
                    onCheckedChanged: root.adSkip = checked
                }
            }
        }

        ListItem {
            height: channelLayout.height + (divider.visible ? divider.height : 0)
            enabled: root.adSkip
            onClicked: root.chooseBreakChannel()

            ListItemLayout {
                id: channelLayout
                title.text: "Channel during ads"
                subtitle.text: root.breakChannel ? root.breakChannel.name : "None chosen yet"
                ProgressionSlot {}
            }
        }

        Item {
            width: 1
            height: units.gu(2)
        }

        Label {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            wrapMode: Text.WordWrap
            color: theme.palette.normal.backgroundSecondaryText
            text: "Revell T.V watches for ad breaks on channels that mark them, which includes most "
                  + "Pluto TV channels. When a break starts it switches to the channel above and goes "
                  + "back when the break is over. Tap “Back now” to return early."
        }
    }
}
