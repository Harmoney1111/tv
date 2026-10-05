.pragma library

// Ad-break rules, ported from the Roku app (AdRules.brs and AdWatchTask.brs).
//
// Many free channels announce their breaks in the playlist (CUE-OUT / CUE-IN and
// DATERANGE markers); Pluto TV gives its ad segments tell-tale addresses instead.

// Some providers (Pluto TV) give their ad segments tell-tale addresses.
function adLikeUrl(url) {
    var lower = url.toLowerCase();
    return lower.indexOf("creative") >= 0 || lower.indexOf("adbumper") >= 0
        || lower.indexOf("ad_bumper") >= 0 || lower.indexOf("_ad%2f") >= 0
        || lower.indexOf("_ad/") >= 0;
}

// Reads a media playlist. The viewer is lagSegments behind the newest segment;
// "soon" looks two segments closer to it, about the time it takes to restart a channel.
// Returns null when the playlist has no segments.
function analyse(text, lagSegments) {
    var segments = [];
    var inBreak = false;
    var sawBreakStart = false;
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf("#EXT-X-CUE-OUT") === 0) {
            inBreak = true;
            sawBreakStart = true;
        } else if (line.indexOf("#EXT-X-CUE-IN") === 0) {
            // A break that began before this playlist window: everything so far was ads.
            if (!sawBreakStart) {
                for (var s = 0; s < segments.length; s++) {
                    segments[s] = true;
                }
            }
            inBreak = false;
        } else if (line.indexOf("#EXT-X-DATERANGE") === 0) {
            if (line.indexOf("SCTE35-OUT") >= 0) {
                inBreak = true;
                sawBreakStart = true;
            }
            if (line.indexOf("SCTE35-IN") >= 0) {
                inBreak = false;
            }
        } else if (line !== "" && line.charAt(0) !== "#") {
            segments.push(inBreak || adLikeUrl(line));
        }
    }

    var count = segments.length;
    if (count === 0) {
        return null;
    }
    var viewer = Math.max(count - 1 - lagSegments, 0);
    var soon = Math.min(viewer + 2, count - 1);
    return { nowAd: segments[viewer], soonAd: segments[soon] };
}

// Pluto hands out per-viewer addresses through a redirect that this phone's
// XMLHttpRequest follows without saying where it went, so rebuild where it leads.
function playlistBase(url) {
    var mark = url.indexOf("jmp2.uk/plu-");
    if (mark < 0) {
        return url;
    }
    var channel = url.substring(mark + 12).split(".")[0];
    return "https://stitcher-ipv4.pluto.tv/v2/stitch/embed/hls/channel/" + channel + "/master.m3u8";
}

// The first variant of a master playlist, or "" when the text is already a media playlist.
function firstVariant(text, base) {
    if (text.indexOf("#EXT-X-STREAM-INF") < 0) {
        return "";
    }
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line !== "" && line.charAt(0) !== "#") {
            return resolveUrl(base, line);
        }
    }
    return "";
}

function resolveUrl(base, reference) {
    var lower = reference.toLowerCase();
    if (lower.indexOf("http://") === 0 || lower.indexOf("https://") === 0) {
        return reference;
    }
    base = base.split("?")[0];
    var schemeEnd = base.indexOf("://");
    if (reference.indexOf("//") === 0) {
        return base.substring(0, schemeEnd + 1) + reference;
    }
    var hostEnd = base.indexOf("/", schemeEnd + 3);
    if (reference.charAt(0) === "/") {
        return hostEnd < 0 ? base + reference : base.substring(0, hostEnd) + reference;
    }
    var lastSlash = base.lastIndexOf("/");
    if (lastSlash <= schemeEnd + 2) {
        return base + "/" + reference;
    }
    return base.substring(0, lastSlash + 1) + reference;
}
