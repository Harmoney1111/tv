// Revell T.V for Ubuntu Touch: loads the channel list from GitHub Pages at every start,
// shows Saved, Popular, All channels and the categories, and plays a channel when tapped.
// Saved channels and the ad skip choices are remembered on the phone.
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
    property bool openedFromArguments: false

    property alias adSkip: settings.adSkip
    readonly property var breakChannel: findBreakChannel(channels, settings.breakChannelId)

    Settings {
        id: settings
        property string saved: "[]"
        property bool adSkip: true
        property string breakChannelId: ""
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
            openFromArguments();
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

    // The chosen channel, or MTV Biggest Pop like on the Roku, or else the first music channel.
    function findBreakChannel(list, id) {
        var fallback = null;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                return list[i];
            }
        }
        for (var m = 0; m < list.length; m++) {
            if (list[m].group !== "Music") {
                continue;
            }
            if (list[m].name.toLowerCase().indexOf("mtv biggest pop") === 0) {
                return list[m];
            }
            fallback = fallback || list[m];
        }
        return fallback;
    }

    function setBreakChannel(channel) {
        settings.breakChannelId = channel.id;
    }

    // "revelltv:<start of a channel name>" on the command line opens that channel,
    // e.g. lomiri-app-launch <app id> "revelltv:MTV%20Biggest%20Pop".
    function openFromArguments() {
        if (openedFromArguments) {
            return;
        }
        openedFromArguments = true;
        var args = Qt.application.arguments;
        for (var i = 0; i < args.length; i++) {
            if (args[i].indexOf("revelltv:") !== 0) {
                continue;
            }
            var wanted = decodeURIComponent(args[i].substring(9)).toLowerCase();
            for (var c = 0; c < channels.length; c++) {
                if (channels[c].name.toLowerCase().indexOf(wanted) === 0) {
                    watch(channels, c);
                    return;
                }
            }
        }
    }

    function openAdSkip() {
        stack.push(adSkipPage);
    }

    function chooseBreakChannel() {
        stack.push(breakChannelPage);
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
    Component { id: adSkipPage; AdSkipPage {} }
    Component { id: breakChannelPage; BreakChannelPage {} }

    PageStack {
        id: stack
    }

    Component.onCompleted: {
        stack.push(homePage);
        load();
    }
}
