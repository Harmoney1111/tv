' Pluto TV channels. The channel list gives them as jmp2.uk/plu-<id> addresses, which
' Pluto stopped serving in October 2026 ("channel not permitted for partner"). The app
' now opens a Pluto session itself, the way Pluto's own players do, and plays the
' address Pluto hands back for it. Every session is good for one channel at a time.

' The Pluto channel id in a jmp2.uk/plu-<id> address, or "" for any other channel.
function plutoChannelId(url as string) as string
    mark = Instr(1, url, "jmp2.uk/plu-")
    if mark = 0 then return ""
    channel = Mid(url, mark + 12)
    dot = Instr(1, channel, ".")
    if dot > 0 then channel = Left(channel, dot - 1)
    return channel
end function

' Opens a new Pluto session and returns the channel's address in it, or "" when
' Pluto does not answer. It goes over the network, so call it from a Task only.
function plutoSessionUrl(channelId as string, clientId as string) as string
    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.EnableEncodings(true)
    request.SetUrl("https://boot.pluto.tv/v4/start?appName=roku&appVersion=5.0.0&deviceType=roku&deviceMake=Roku&deviceModel=roku&deviceVersion=unknown&clientModelNumber=1.0.0&serverSideAds=false&clientID=" + clientId)

    if not request.AsyncGetToString() then return ""
    event = wait(15000, port)
    if type(event) <> "roUrlEvent" then return ""
    if event.GetResponseCode() <> 200 then return ""

    boot = ParseJson(event.GetString())
    if type(boot) <> "roAssociativeArray" then return ""
    if type(boot.servers) <> "roAssociativeArray" then return ""
    stitcher = boot.servers.stitcher
    if not isText(stitcher) or not isText(boot.stitcherParams) or not isText(boot.sessionToken) then return ""

    return stitcher + "/v2/stitch/hls/channel/" + channelId + "/master.m3u8?" + boot.stitcherParams + "&jwt=" + boot.sessionToken + "&masterJWTPassthrough=true"
end function

function isText(value as dynamic) as boolean
    kind = type(value)
    return kind = "String" or kind = "roString"
end function
