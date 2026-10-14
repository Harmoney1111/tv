.pragma library

// Plex channels, ported from the Roku app (Plex.brs).
//
// They come in a list of their own, plex.m3u, next to the main list. Plex serves its
// free channels to anyone with a Plex token, and an anonymous one, as Plex's own web
// player gets, is enough. The app asks for one when it loads the lists and adds it to
// every Plex channel's address.

// Calls done(token) with a new anonymous Plex token, or done("") when Plex does not answer.
function token(clientId, done) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
            return;
        }
        var reply = null;
        try {
            reply = xhr.status === 200 || xhr.status === 201 ? JSON.parse(xhr.responseText) : null;
        } catch (e) {
        }
        done(reply && typeof reply.authToken === "string" ? reply.authToken : "");
    };
    xhr.open("POST", "https://clients.plex.tv/api/v2/users/anonymous");
    xhr.setRequestHeader("Accept", "application/json");
    xhr.setRequestHeader("X-Plex-Product", "Plex Web");
    xhr.setRequestHeader("X-Plex-Version", "4.145.0");
    xhr.setRequestHeader("X-Plex-Client-Identifier", clientId);
    xhr.send();
}
