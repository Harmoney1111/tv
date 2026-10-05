.pragma library

// Reads the M3U list the same way the Roku app does. A channel's category is the first
// entry of group-title that is not "Popular"; "Popular" is an extra tag.

function parse(text) {
    var channels = [];
    var lines = text.split(/\r?\n/);
    var info = "";
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf("#EXTINF") === 0) {
            info = line;
        } else if (info !== "" && line !== "" && line.charAt(0) !== "#") {
            channels.push(makeChannel(info, line));
            info = "";
        }
    }
    return channels;
}

function attribute(line, name) {
    var match = new RegExp(name + '="([^"]*)"', "i").exec(line);
    return match ? match[1] : "";
}

function makeChannel(info, url) {
    var group = "Other";
    var popular = false;
    var parts = attribute(info, "group-title").split(";");
    for (var i = 0; i < parts.length; i++) {
        var part = parts[i].trim();
        if (part === "Popular") {
            popular = true;
        } else if (group === "Other" && part !== "" && part.toLowerCase() !== "undefined") {
            group = part;
        }
    }
    // The name follows the comma after the last attribute.
    var end = info.lastIndexOf('",');
    var name = end >= 0 ? info.substring(end + 2) : info.substring(info.indexOf(",") + 1);
    return {
        id: attribute(info, "tvg-id") || url,
        name: name.trim(),
        logo: attribute(info, "tvg-logo"),
        group: group,
        popular: popular,
        url: url
    };
}

// Saved, Popular, All channels, then the categories A to Z with "Other" last.
function sections(channels, saved) {
    var groups = {};
    var popular = [];
    for (var i = 0; i < channels.length; i++) {
        var channel = channels[i];
        (groups[channel.group] = groups[channel.group] || []).push(channel);
        if (channel.popular) {
            popular.push(channel);
        }
    }
    var names = Object.keys(groups).filter(function (name) { return name !== "Other"; }).sort();
    if (groups["Other"]) {
        names.push("Other");
    }
    var list = [{ name: "Saved", channels: saved }];
    if (popular.length > 0) {
        list.push({ name: "Popular", channels: popular });
    }
    list.push({ name: "All channels", channels: channels });
    for (var n = 0; n < names.length; n++) {
        list.push({ name: names[n], channels: groups[names[n]] });
    }
    return list;
}

function search(channels, text) {
    var words = text.toLowerCase().split(/\s+/).filter(function (word) { return word !== ""; });
    return channels.filter(function (channel) {
        var haystack = (channel.name + " " + channel.group).toLowerCase();
        return words.every(function (word) { return haystack.indexOf(word) >= 0; });
    });
}
