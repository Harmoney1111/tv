// Revell T.V for Ubuntu Touch: loads the channel list from GitHub Pages at every start,
// shows Saved, Popular, All channels and the categories, and plays a channel when tapped.
// Saved channels are remembered on the phone.
import QtQuick 2.12
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import "channels.js" as Channels

MainView {
    id: root
    applicationName: "revell-tv.harmoney1111"
    width: units.gu(45)
    height: units.gu(75)
    backgroundColor: "#0A081C"
    theme.name: "Lomiri.Components.Themes.SuruDark"

    readonly property string listAddress: "https://harmoney1111.github.io/tv/english-tv.m3u"
    readonly property color accent: "#FF2E93"

    property var channels: []
    property var savedIds: ({})
    property var savedChannels: []
    property string listState: "loading"   // loading, ready or failed

    Settings {
        id: settings
        property string saved: "[]"
    }

    function load() {
        listState = "loading";
        var request = new XMLHttpRequest();
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            var list = request.status === 200 ? Channels.parse(request.responseText) : [];
            if (list.length === 0) {
                listState = "failed";
                return;
            }
            channels = list;
            refreshSaved();
            listState = "ready";
        };
        request.open("GET", listAddress);
        request.send();
    }

    function refreshSaved() {
        var ids = {};
        try {
            JSON.parse(settings.saved).forEach(function (id) { ids[id] = true; });
        } catch (e) {
        }
        savedIds = ids;
        savedChannels = channels.filter(function (channel) { return ids[channel.id] === true; });
    }

    function toggleSaved(channel) {
        var ids = Object.keys(savedIds).filter(function (id) { return id !== channel.id; });
        if (savedIds[channel.id] !== true) {
            ids.push(channel.id);
        }
        settings.saved = JSON.stringify(ids);
        refreshSaved();
    }

    function openChannels(title, list) {
        stack.push(channelsPage, { title: title, channels: list, savedList: title === "Saved" });
    }

    function watch(list, index) {
        stack.push(playerPage, { channels: list, index: index });
    }

    // The pages are made here so they can reach this file's functions through "root".
    Component { id: homePage; HomePage {} }
    Component { id: channelsPage; ChannelsPage {} }
    Component { id: playerPage; PlayerPage {} }

    PageStack {
        id: stack
    }

    Component.onCompleted: {
        stack.push(homePage);
        load();
    }
}
