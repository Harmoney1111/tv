.pragma library
.import "adwatch.js" as AdWatch

// The phone's hardware video decoder fails when a stream changes picture size
// ("Buffer pool activation failed" in the media-hub log), and adaptive streams do that
// a few seconds in, once they have measured the connection. So the player gets a single
// variant of the master playlist: the sharpest one up to 720 lines.
//
// Most channels keep picture and sound together and play that variant's playlist.
// Some (most of Pluto TV) keep the sound in playlists of its own; they get a master
// playlist of one variant and its sound, which the player page saves to a file (the
// phone's media service turns data: addresses away).

var MAX_HEIGHT = 720;
var MAX_BANDWIDTH = 3500000;   // for variants that do not give their picture size

// What to play instead of the master playlist at `base`: { url } of one variant,
// { playlist } holding a master playlist of one variant and its sound, or null to play
// the master itself (a media playlist already, or nothing to choose from).
function steadyChoice(text, base) {
    if (text.indexOf("#EXT-X-STREAM-INF") < 0) {
        return null;
    }
    var lines = text.split("\n").map(function (line) { return line.trim(); });
    var variants = [];
    for (var i = 0; i < lines.length; i++) {
        if (lines[i].indexOf("#EXT-X-STREAM-INF") !== 0) {
            continue;
        }
        for (var j = i + 1; j < lines.length; j++) {
            if (lines[j] !== "" && lines[j].charAt(0) !== "#") {
                variants.push({
                    info: lines[i],
                    url: AdWatch.resolveUrl(base, lines[j]),
                    height: number(/RESOLUTION=\d+x(\d+)/.exec(lines[i])),
                    bandwidth: number(/(?:^|[:,])BANDWIDTH=(\d+)/.exec(lines[i])),
                    audio: attribute(lines[i], "AUDIO")
                });
                break;
            }
        }
    }
    if (variants.length === 0) {
        return null;
    }

    var best = variants[0];
    for (var v = 1; v < variants.length; v++) {
        if (better(variants[v], best)) {
            best = variants[v];
        }
    }

    var sound = lines.filter(function (line) {
        return line.indexOf("#EXT-X-MEDIA:") === 0 && line.indexOf("TYPE=AUDIO") >= 0
            && line.indexOf("URI=") >= 0 && best.audio !== "" && attribute(line, "GROUP-ID") === best.audio;
    });
    if (sound.length === 0) {
        return { url: best.url };
    }
    var master = ["#EXTM3U", "#EXT-X-VERSION:5"];
    sound.forEach(function (line) {
        master.push(line.replace(/URI="([^"]*)"/, function (all, uri) {
            return 'URI="' + AdWatch.resolveUrl(base, uri) + '"';
        }));
    });
    // Subtitles and captions are left out, so the variant must not point at them.
    master.push(best.info.replace(/,(SUBTITLES|CLOSED-CAPTIONS)=("[^"]*"|[^,]*)/g, ""));
    master.push(best.url);
    return { playlist: master.join("\n") + "\n" };
}

// Up to 720 lines the sharpest (then the richest) wins, above that the smallest. Without
// picture sizes the richest up to MAX_BANDWIDTH wins, or else the poorest.
function better(a, b) {
    var aFits = a.height > 0 ? a.height <= MAX_HEIGHT : a.bandwidth <= MAX_BANDWIDTH;
    var bFits = b.height > 0 ? b.height <= MAX_HEIGHT : b.bandwidth <= MAX_BANDWIDTH;
    if (aFits !== bFits) {
        return aFits;
    }
    if (a.height !== b.height) {
        return aFits ? a.height > b.height : a.height < b.height;
    }
    return aFits ? a.bandwidth > b.bandwidth : a.bandwidth < b.bandwidth;
}

function attribute(line, name) {
    var match = new RegExp("[:,]" + name + '=("([^"]*)"|[^,]*)').exec(line);
    return match ? (match[2] !== undefined ? match[2] : match[1]) : "";
}

function number(match) {
    return match ? parseInt(match[1], 10) : 0;
}
