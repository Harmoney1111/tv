' Plex channels. They come in a list of their own, plex.m3u, which apps before 1.6
' never read. Plex serves its free channels to anyone with a Plex token, and an
' anonymous one, as Plex's own web player gets, is enough. The app asks for one
' when it loads the lists and adds it to every Plex channel's address.

' A new anonymous Plex token, or "" when Plex does not answer. It goes over the
' network, so call it from a Task only.
function plexToken(clientId as string) as string
    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.SetUrl("https://clients.plex.tv/api/v2/users/anonymous")
    request.AddHeader("Accept", "application/json")
    request.AddHeader("X-Plex-Product", "Plex Web")
    request.AddHeader("X-Plex-Version", "4.145.0")
    request.AddHeader("X-Plex-Client-Identifier", clientId)

    if not request.AsyncPostFromString("") then return ""
    event = wait(15000, port)
    if type(event) <> "roUrlEvent" then return ""
    code = event.GetResponseCode()
    if code <> 200 and code <> 201 then return ""

    reply = ParseJson(event.GetString())
    if type(reply) <> "roAssociativeArray" then return ""
    token = reply.authToken
    if type(token) <> "String" and type(token) <> "roString" then return ""
    return token
end function
