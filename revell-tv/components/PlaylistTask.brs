' Downloads the M3U channel list and turns it into categories of channels.
' Also downloads the scanner's penalty box (channels that did not load).

sub init()
    m.top.functionName = "loadPlaylist"
end sub

sub loadPlaylist()
    text = download(m.top.url)
    if text = "" then
        m.top.error = "Could not download the channel list. Check the internet connection, then close and reopen Revell T.V."
        return
    end if

    list = parseChannels(text)
    if list.channels.Count() = 0 then
        m.top.error = "The channel list came back empty. Close and reopen Revell T.V to try again."
        return
    end if

    ' Alphabetical, with the uncategorised channels last.
    names = []
    for each name in list.groups.Keys()
        if name <> "Other" then names.Push(name)
    end for
    if list.groups.DoesExist("Other") then names.Push("Other")

    root = CreateObject("roSGNode", "ContentNode")
    for each name in names
        category = root.CreateChild("ContentNode")
        category.title = name
        addChannels(category, list.groups[name])
    end for

    popularNode = CreateObject("roSGNode", "ContentNode")
    addChannels(popularNode, list.popular)

    ' The penalty box sits next to the main list; the app still works without it.
    penaltyNode = CreateObject("roSGNode", "ContentNode")
    penaltyText = download(m.top.url.Replace("english-tv.m3u", "penalty-box.m3u"))
    if penaltyText <> "" then addChannels(penaltyNode, parseChannels(penaltyText).channels)

    m.top.total = list.channels.Count()
    m.top.popular = popularNode
    m.top.penalty = penaltyNode
    m.top.content = root
end sub

' Returns { channels: every channel in order, groups: name -> channels, popular: channels }.
function parseChannels(text as string) as object
    quote = Chr(34)
    quoteComma = quote + ","
    idRegex = CreateObject("roRegex", "tvg-id=" + quote + "([^" + quote + "]*)", "i")
    groupRegex = CreateObject("roRegex", "group-title=" + quote + "([^" + quote + "]*)", "i")

    lines = text.Split(Chr(10))
    lineCount = lines.Count()
    channels = []
    groups = {}
    popular = []

    i = 0
    while i < lineCount
        line = lines[i].Trim()
        if line.Left(7) = "#EXTINF" then
            ' The address is the next line that is not blank or an option line.
            address = ""
            j = i + 1
            while j < lineCount
                candidate = lines[j].Trim()
                if candidate <> "" and candidate.Left(1) <> "#" then
                    address = candidate
                    exit while
                end if
                if candidate.Left(7) = "#EXTINF" then exit while
                j = j + 1
            end while

            ' The name follows the comma after the last quoted attribute.
            cut = 0
            found = Instr(1, line, quoteComma)
            while found > 0
                cut = found + 1
                found = Instr(found + 1, line, quoteComma)
            end while
            if cut = 0 then cut = Instr(1, line, ",")
            title = Mid(line, cut + 1).Trim()

            ' Categories are separated by semicolons. "Popular" is an extra tag;
            ' the channel is filed under its first real category.
            group = "Other"
            isPopular = false
            match = groupRegex.Match(line)
            if match.Count() > 1 then
                for each part in match[1].Split(";")
                    if part = "Popular" then
                        isPopular = true
                    else if group = "Other" and part <> "" and LCase(part) <> "undefined" then
                        group = part
                    end if
                end for
            end if

            if address <> "" and title <> "" then
                channelId = address
                match = idRegex.Match(line)
                if match.Count() > 1 then
                    if match[1] <> "" then channelId = match[1]
                end if

                lower = LCase(address)
                streamFormat = "hls"
                if Instr(1, lower, ".mpd") > 0 then
                    streamFormat = "dash"
                else if Instr(1, lower, ".mp4") > 0 then
                    streamFormat = "mp4"
                end if

                channel = { id: channelId, title: title, url: address, streamFormat: streamFormat }
                channels.Push(channel)
                if not groups.DoesExist(group) then groups[group] = []
                groups[group].Push(channel)
                if isPopular then popular.Push(channel)
            end if
        end if
        i = i + 1
    end while

    return { channels: channels, groups: groups, popular: popular }
end function

sub addChannels(parent as object, channels as object)
    for each channel in channels
        item = parent.CreateChild("ContentNode")
        item.SetFields(channel)
    end for
end sub

function download(url as string) as string
    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.EnableEncodings(true)
    request.SetUrl(url)

    if not request.AsyncGetToString() then return ""
    event = wait(45000, port)
    if type(event) <> "roUrlEvent" then return ""
    if event.GetResponseCode() <> 200 then return ""
    return event.GetString()
end function
