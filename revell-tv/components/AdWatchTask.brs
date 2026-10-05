' Watches a channel's playlist for ad breaks while the channel is being viewed.
'
' Many free channels announce their breaks in the playlist (CUE-OUT / CUE-IN and
' DATERANGE markers); Pluto TV gives its ad segments tell-tale addresses instead.
' Every few seconds this re-reads the playlist and reports whether the viewer is
' in a break now (nowAd) and whether they still will be in a few seconds (soonAd).

sub init()
    m.top.functionName = "watch"
end sub

sub watch()
    playlistUrl = findMediaPlaylist(m.top.url)
    if playlistUrl = "" then return
    print "ad watch: following "; playlistUrl.Left(110)

    while true
        text = fetchText(playlistUrl).text
        if text <> "" then report(text)
        sleep(4000)
    end while
end sub

sub report(text as string)
    segments = []
    inBreak = false
    sawBreakStart = false
    sequence = 0

    for each raw in text.Split(Chr(10))
        line = raw.Trim()
        if line.Left(22) = "#EXT-X-MEDIA-SEQUENCE:" then
            sequence = Mid(line, 23).ToInt()
        else if line.Left(14) = "#EXT-X-CUE-OUT" then
            inBreak = true
            sawBreakStart = true
        else if line.Left(13) = "#EXT-X-CUE-IN" then
            ' A break that began before this playlist window: everything so far was ads.
            if not sawBreakStart then
                for each segment in segments
                    segment.ad = true
                end for
            end if
            inBreak = false
        else if line.Left(16) = "#EXT-X-DATERANGE" then
            if Instr(1, line, "SCTE35-OUT") > 0 then
                inBreak = true
                sawBreakStart = true
            end if
            if Instr(1, line, "SCTE35-IN") > 0 then inBreak = false
        else if line <> "" and line.Left(1) <> "#" then
            segments.Push({ ad: inBreak or adLikeUrl(line) })
        end if
    end for

    count = segments.Count()
    if count = 0 then return

    ' The viewer is lagSegments behind the newest segment. "Soon" looks two
    ' segments closer to it, about the time it takes to restart the channel.
    viewer = count - 1 - m.top.lagSegments
    if viewer < 0 then viewer = 0
    soon = viewer + 2
    if soon > count - 1 then soon = count - 1

    m.top.edge = sequence + count - 1
    m.top.usable = true
    m.top.nowAd = segments[viewer].ad
    m.top.soonAd = segments[soon].ad
end sub

' Follows a master playlist to the first of its variants.
function findMediaPlaylist(url as string) as string
    response = fetchText(url)
    if response.text = "" then return ""
    base = response.finalUrl

    ' Pluto hands out per-viewer addresses through a redirect. If the redirect
    ' did not show up in the response, rebuild the address it leads to.
    if base = url then
        mark = Instr(1, url, "jmp2.uk/plu-")
        if mark > 0 then
            channel = Mid(url, mark + 12)
            dot = Instr(1, channel, ".")
            if dot > 0 then channel = Left(channel, dot - 1)
            base = "https://stitcher-ipv4.pluto.tv/v2/stitch/embed/hls/channel/" + channel + "/master.m3u8"
        end if
    end if

    if Instr(1, response.text, "#EXT-X-STREAM-INF") = 0 then return base
    for each raw in response.text.Split(Chr(10))
        line = raw.Trim()
        if line <> "" and line.Left(1) <> "#" then return resolveUrl(base, line)
    end for
    return ""
end function

' Returns { text, finalUrl }. finalUrl follows any redirects that were reported.
function fetchText(url as string) as object
    result = { text: "", finalUrl: url }
    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.EnableEncodings(true)
    request.SetUrl(url)

    if not request.AsyncGetToString() then return result
    event = wait(15000, port)
    if type(event) <> "roUrlEvent" then return result
    if event.GetResponseCode() <> 200 then return result

    for each header in event.GetResponseHeadersArray()
        for each name in header
            if LCase(name) = "location" then result.finalUrl = resolveUrl(result.finalUrl, header[name])
        end for
    end for
    result.text = event.GetString()
    return result
end function

function resolveUrl(base as string, reference as string) as string
    lower = LCase(reference)
    if lower.Left(7) = "http://" or lower.Left(8) = "https://" then return reference

    query = Instr(1, base, "?")
    if query > 0 then base = Left(base, query - 1)
    schemeEnd = Instr(1, base, "://")
    if reference.Left(2) = "//" then return Left(base, schemeEnd) + reference

    hostEnd = Instr(schemeEnd + 3, base, "/")
    if reference.Left(1) = "/" then
        if hostEnd = 0 then return base + reference
        return Left(base, hostEnd - 1) + reference
    end if

    lastSlash = 0
    found = Instr(1, base, "/")
    while found > 0
        lastSlash = found
        found = Instr(found + 1, base, "/")
    end while
    if lastSlash <= schemeEnd + 2 then return base + "/" + reference
    return Left(base, lastSlash) + reference
end function
