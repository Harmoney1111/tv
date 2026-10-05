' Revell T.V: a menu on the left, channels on the right, OK to watch.
'
' Menu: Search, Saved, Popular, the categories, Penalty box, Ad skip.
' Saved channels, the penalty box and the ad-skip choices are remembered on the Roku.
'
' Ad skip: while a channel plays, AdWatchTask and the player's own segment
' reports say when an ad break starts. The music channel then stands in until
' the break is over.
'
' Back while watching keeps the channel playing in a window beside the list;
' picking it again makes it full screen, and Back on the menu stops it.

sub init()
    m.menuList = m.top.findNode("categories")
    m.channels = m.top.findNode("channels")
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.message = m.top.findNode("message")
    m.banner = m.top.findNode("breakBanner")
    m.bannerText = m.top.findNode("breakBannerText")
    m.breakTimer = m.top.findNode("breakTimer")
    m.preview = m.top.findNode("preview")
    m.previewTitle = m.top.findNode("previewTitle")
    m.previewNote = m.top.findNode("previewNote")

    m.registry = CreateObject("roRegistrySection", "RevellTV")
    m.savedIds = readList("saved")
    m.benchedIds = readList("benched")
    m.adSkip = (readSetting("adskip", "on") = "on")
    m.breakChannelId = readSetting("breakchannel", "")

    m.loaded = false
    m.total = 0
    m.menuItems = []
    m.music = invalid
    m.playing = false      ' a channel is playing, full screen or in the window
    m.fullScreen = false   ' it is full screen and the remote controls it
    m.reachedPlaying = false
    m.playIndex = -1
    m.playId = ""
    m.playTitle = ""
    m.searchTerm = ""

    m.main = invalid       ' the channel the viewer chose to watch
    m.watch = invalid      ' AdWatchTask following that channel
    m.onBreak = false      ' the music channel is standing in for an ad break
    m.breakHold = false    ' the viewer asked to stay on the channel through this break
    m.segmentArmed = false ' the player has shown some programme since the stream started

    m.menuList.observeField("itemFocused", "onMenuFocused")
    m.menuList.observeField("itemSelected", "onMenuSelected")
    m.channels.observeField("itemSelected", "onChannelSelected")
    m.video.observeField("state", "onVideoState")
    m.video.observeField("streamingSegment", "onSegment")
    m.breakTimer.observeField("fire", "onBreakTimer")

    m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.observeField("content", "onPlaylistLoaded")
    m.task.observeField("error", "onPlaylistError")
    m.task.url = "https://harmoney1111.github.io/tv/english-tv.m3u"
    m.task.control = "RUN"
end sub

' ---------- remembered settings ----------

function readList(key as string) as object
    if m.registry.Exists(key) then
        stored = ParseJson(m.registry.Read(key))
        if type(stored) = "roArray" then return stored
    end if
    return []
end function

sub writeList(key as string, values as object)
    m.registry.Write(key, FormatJson(values))
    m.registry.Flush()
end sub

function readSetting(key as string, fallback as string) as string
    if m.registry.Exists(key) then return m.registry.Read(key)
    return fallback
end function

sub writeSetting(key as string, value as string)
    m.registry.Write(key, value)
    m.registry.Flush()
end sub

function indexOf(values as object, value as string) as integer
    position = 0
    for each entry in values
        if entry = value then return position
        position = position + 1
    end for
    return -1
end function

' ---------- loading ----------

sub onPlaylistLoaded()
    m.playlist = m.task.content
    m.popular = m.task.popular
    m.total = m.task.total

    benched = {}
    for each id in m.benchedIds
        benched[id] = true
    end for

    ' The penalty box starts with the channels the scanner could not load;
    ' channels that failed on this Roku before join them.
    m.penalty = m.task.penalty
    m.byId = {}
    for each item in m.penalty.getChildren(-1, 0)
        if not m.byId.DoesExist(item.id) then m.byId[item.id] = item
    end for
    for each category in m.playlist.getChildren(-1, 0)
        if category.title = "Music" then m.music = category
        for each item in category.getChildren(-1, 0)
            if not m.byId.DoesExist(item.id) then m.byId[item.id] = item
            if benched.DoesExist(item.id) then m.penalty.appendChild(item)
        end for
    end for
    for each item in m.popular.getChildren(-1, 0)
        if benched.DoesExist(item.id) then m.popular.removeChild(item)
    end for

    if not m.byId.DoesExist(m.breakChannelId) then m.breakChannelId = defaultBreakChannel()

    m.saved = CreateObject("roSGNode", "ContentNode")
    m.results = CreateObject("roSGNode", "ContentNode")
    rebuildSaved()
    buildMenu()

    m.loaded = true
    m.message.visible = false

    ' Open on Saved when there is something in it, otherwise on the entry after it.
    start = 1
    if m.saved.getChildCount() = 0 then start = 2
    m.menuList.jumpToItem = start
    m.menuList.setFocus(true)
    showMenu(start)
end sub

sub onPlaylistError()
    m.message.text = m.task.error
    m.message.visible = true
end sub

sub rebuildSaved()
    m.saved.removeChildrenIndex(m.saved.getChildCount(), 0)
    for each id in m.savedIds
        if m.byId.DoesExist(id) then m.saved.appendChild(m.byId[id].clone(false))
    end for
end sub

' ---------- menu ----------

sub buildMenu()
    m.menu = CreateObject("roSGNode", "ContentNode")
    m.menuItems = []
    addMenu("search", "Search", invalid)
    addMenu("saved", "Saved", m.saved)
    if m.popular.getChildCount() > 0 then addMenu("popular", "Popular", m.popular)
    for each category in m.playlist.getChildren(-1, 0)
        addMenu("category", category.title, category)
    end for
    addMenu("penalty", "Penalty box", m.penalty)
    addMenu("adskip", "Ad skip", m.music)
    refreshMenuTitles()
    m.menuList.content = m.menu
end sub

sub addMenu(kind as string, name as string, node as dynamic)
    entry = m.menu.CreateChild("ContentNode")
    m.menuItems.Push({ kind: kind, name: name, node: node, entry: entry })
end sub

sub refreshMenuTitles()
    for each menuItem in m.menuItems
        if menuItem.kind = "adskip" then
            if m.adSkip then
                menuItem.entry.title = "Ad skip: ON"
            else
                menuItem.entry.title = "Ad skip: OFF"
            end if
        else if menuItem.node = invalid then
            menuItem.entry.title = menuItem.name
        else
            menuItem.entry.title = menuItem.name + "  (" + menuItem.node.getChildCount().ToStr() + ")"
        end if
    end for
end sub

sub showMenu(index as integer)
    if index < 0 or index >= m.menuItems.Count() then return
    menuItem = m.menuItems[index]
    if menuItem.kind = "search" then
        m.channels.content = m.results
    else if menuItem.node <> invalid then
        m.channels.content = menuItem.node
    end if
end sub

sub onMenuFocused()
    if not m.loaded then return
    index = m.menuList.itemFocused
    showMenu(index)
    if index >= 0 and index < m.menuItems.Count() and m.menuItems[index].kind = "adskip" then
        m.status.text = adSkipSummary()
    else
        m.status.text = m.total.ToStr() + " channels"
    end if
end sub

sub onMenuSelected()
    menuItem = m.menuItems[m.menuList.itemSelected]
    if menuItem.kind = "search" then
        openSearch()
    else if menuItem.kind = "adskip" then
        m.adSkip = not m.adSkip
        if m.adSkip then
            writeSetting("adskip", "on")
        else
            writeSetting("adskip", "off")
        end if
        refreshMenuTitles()
        m.status.text = adSkipSummary()
    else
        focusChannels()
    end if
end sub

sub focusChannels()
    shown = m.channels.content
    if shown <> invalid and shown.getChildCount() > 0 then m.channels.setFocus(true)
end sub

' ---------- watching ----------

sub onChannelSelected()
    index = m.channels.itemSelected
    shown = m.channels.content
    if m.playing and not m.fullScreen and shown <> invalid then
        item = shown.getChild(index)
        ' Picking the channel that is playing in the window just makes it full screen.
        if item <> invalid and item.id = m.playId then
            m.playIndex = index
            showFullScreen()
            return
        end if
    end if
    playChannel(index)
end sub

sub playChannel(index as integer)
    shown = m.channels.content
    if shown = invalid then return
    item = shown.getChild(index)
    if item = invalid then return

    m.playIndex = index
    m.playId = item.id
    m.playTitle = item.title
    m.main = { id: item.id, title: item.title, url: item.url, streamFormat: item.streamFormat }
    m.playing = true
    m.reachedPlaying = false
    m.onBreak = false
    m.breakHold = false
    m.banner.visible = false
    showFullScreen()
    startStream(m.main)
    startWatch()
end sub

sub startStream(channel as object)
    ' Every new Pluto session opens with an ad bumper, so the player's own ad
    ' segments only count once it has shown some of the programme.
    m.segmentArmed = false
    content = CreateObject("roSGNode", "ContentNode")
    content.title = channel.title
    content.url = channel.url
    content.streamFormat = channel.streamFormat
    content.live = true
    m.video.content = content
    m.video.visible = true
    if m.fullScreen then m.video.setFocus(true)
    m.video.control = "play"
end sub

sub stopVideo()
    wasFullScreen = m.fullScreen
    m.playing = false
    m.fullScreen = false
    m.onBreak = false
    m.banner.visible = false
    stopWatch()
    m.video.control = "stop"
    m.video.visible = false
    m.preview.visible = false
    m.channels.itemSize = [800, 48]
    ' From the window the viewer is already in the lists; leave the focus where it is.
    if wasFullScreen then
        m.channels.setFocus(true)
        if m.playIndex >= 0 then m.channels.jumpToItem = m.playIndex
    end if
end sub

' ---------- preview window ----------

sub showFullScreen()
    m.fullScreen = true
    m.preview.visible = false
    m.channels.itemSize = [800, 48]
    m.video.translation = [0, 0]
    m.video.width = 1280
    m.video.height = 720
    m.banner.visible = m.onBreak
    m.video.setFocus(true)
end sub

sub showPreview()
    m.fullScreen = false
    m.banner.visible = false
    m.channels.itemSize = [400, 48]
    m.video.translation = [836, 120]
    m.video.width = 384
    m.video.height = 216
    updatePreviewNote()
    m.preview.visible = true
    m.channels.setFocus(true)
    if m.playIndex >= 0 then m.channels.jumpToItem = m.playIndex
end sub

sub updatePreviewNote()
    if m.main = invalid then return
    m.previewTitle.text = m.main.title
    if m.onBreak and m.byId.DoesExist(m.breakChannelId) then
        m.previewNote.text = "Ad break: " + m.byId[m.breakChannelId].title + " until it is over"
    else
        m.previewNote.text = "Pick it again for full screen. Back on the menu stops it."
    end if
end sub

sub onVideoState()
    if not m.playing then return
    state = m.video.state

    if m.onBreak then
        ' The music channel let us down: go back to the show and sit this break out.
        if state = "error" or state = "finished" then
            print "ad skip: music channel failed"
            leaveBreak(true)
        end if
        return
    end if

    if state = "playing" then
        m.reachedPlaying = true
        releaseChannel(m.playId)
    else if state = "error" then
        print "video error: "; m.video.errorCode; " "; m.video.errorMsg; " "; m.video.content.url
        failedId = m.playId
        failedTitle = m.playTitle
        neverPlayed = not m.reachedPlaying
        stopVideo()
        if neverPlayed then
            benchChannel(failedId)
            m.status.text = failedTitle + " is not working. Moved to the penalty box."
        else
            m.status.text = failedTitle + " stopped. Try it again, or pick another one."
        end if
    else if state = "finished" then
        stopVideo()
    end if
end sub

' ---------- ad skip ----------

function adSkipSummary() as string
    if not m.adSkip then return "Ad skip is off. Press OK to turn it on."
    if not m.byId.DoesExist(m.breakChannelId) then return "Ad skip is on. Press Play on a channel to use it during ads."
    return "During ads: " + m.byId[m.breakChannelId].title + ". Press Play on any channel to change it."
end function

function defaultBreakChannel() as string
    if m.music = invalid then return ""
    fallback = ""
    for each item in m.music.getChildren(-1, 0)
        if fallback = "" then fallback = item.id
        if LCase(item.title).Left(15) = "mtv biggest pop" then return item.id
    end for
    return fallback
end function

sub setBreakChannel()
    shown = m.channels.content
    if shown = invalid then return
    item = shown.getChild(m.channels.itemFocused)
    if item = invalid then return
    m.breakChannelId = item.id
    writeSetting("breakchannel", item.id)
    m.status.text = "During ads Revell T.V will switch to: " + item.title
end sub

sub startWatch()
    stopWatch()
    if not m.adSkip then return
    if not m.byId.DoesExist(m.breakChannelId) then return
    if m.main.id = m.breakChannelId then return

    m.watch = CreateObject("roSGNode", "AdWatchTask")
    m.watch.observeField("nowAd", "onAdSignal")
    m.watch.observeField("soonAd", "onAdSignal")
    m.watch.url = m.main.url
    m.watch.control = "RUN"
end sub

sub stopWatch()
    m.breakTimer.control = "stop"
    if m.watch = invalid then return
    m.watch.unobserveField("nowAd")
    m.watch.unobserveField("soonAd")
    m.watch.control = "STOP"
    m.watch = invalid
end sub

function watchUsable() as boolean
    if m.watch = invalid then return false
    return m.watch.usable
end function

' The playlist watcher changed its mind about whether the viewer is in a break.
sub onAdSignal()
    if not m.playing or m.watch = invalid then return
    if m.onBreak then
        if not m.watch.soonAd then
            print "ad skip: break ending, back to "; m.main.title
            leaveBreak(false)
        end if
    else if m.watch.nowAd then
        enterBreak("playlist marker")
    else
        m.breakHold = false
    end if
end sub

' The player reports each segment it downloads. That tells us how far behind
' the newest segment it is, and on Pluto the address itself gives ads away.
sub onSegment()
    if not m.playing or m.onBreak or not m.adSkip then return
    segment = m.video.streamingSegment
    if segment = invalid or segment.segUrl = invalid then return

    if watchUsable() and segment.segSequence <> invalid then
        lag = m.watch.edge - segment.segSequence
        if lag >= 0 and lag <= 60 and lag <> m.watch.lagSegments then
            print "ad skip: player is "; lag; " segments behind the newest"
            m.watch.lagSegments = lag
        end if
    end if

    if adLikeUrl(segment.segUrl) then
        if m.segmentArmed then enterBreak("ad segment")
    else
        m.segmentArmed = true
        if m.breakHold and not watchUsable() then m.breakHold = false
    end if
end sub

sub enterBreak(reason as string)
    if m.onBreak or m.breakHold or not m.adSkip then return
    if not m.byId.DoesExist(m.breakChannelId) then return
    music = m.byId[m.breakChannelId]

    print "ad skip: break on "; m.main.title; " ("; reason; "), switching to "; music.title
    m.onBreak = true
    ' The Roku keeps * for its captions menu while video plays, so OK is the way out.
    m.bannerText.text = "Ad break on " + m.main.title + "   -   " + music.title + " until it is over   -   press OK to return now"
    m.banner.visible = m.fullScreen
    updatePreviewNote()
    startStream({ title: music.title, url: music.url, streamFormat: music.streamFormat })

    ' When the playlist cannot tell us the break is over, go back and look after a while.
    if not watchUsable() then
        m.breakTimer.control = "stop"
        m.breakTimer.control = "start"
    end if
end sub

sub leaveBreak(hold as boolean)
    if not m.onBreak then return
    m.onBreak = false
    ' Never go back to music for the same break: if the playlist says its tail is
    ' still running, wait it out. The hold lifts when the show is back.
    if watchUsable() then
        m.breakHold = m.watch.nowAd
    else
        m.breakHold = hold
    end if
    m.breakTimer.control = "stop"
    m.banner.visible = false
    updatePreviewNote()
    startStream(m.main)
end sub

sub onBreakTimer()
    if m.onBreak then
        print "ad skip: checking whether the break is over"
        leaveBreak(false)
    end if
end sub

' ---------- penalty box ----------

sub benchChannel(id as string)
    ' Nothing to do for a channel the scanner already put in the box.
    if m.byId.DoesExist(id) then
        parent = m.byId[id].getParent()
        if parent <> invalid and parent.isSameNode(m.penalty) then return
    end if

    if indexOf(m.benchedIds, id) < 0 then
        m.benchedIds.Push(id)
        while m.benchedIds.Count() > 300
            m.benchedIds.Shift()
        end while
        writeList("benched", m.benchedIds)
    end if

    if m.byId.DoesExist(id) then m.penalty.appendChild(m.byId[id])
    for each item in m.popular.getChildren(-1, 0)
        if item.id = id then m.popular.removeChild(item)
    end for
    refreshMenuTitles()
end sub

' A benched channel that plays again is let out; it is back in its category the next time the app opens.
sub releaseChannel(id as string)
    position = indexOf(m.benchedIds, id)
    if position < 0 then return
    m.benchedIds.Delete(position)
    writeList("benched", m.benchedIds)
end sub

' ---------- saved channels ----------

sub toggleSaved()
    shown = m.channels.content
    if shown = invalid then return
    item = shown.getChild(m.channels.itemFocused)
    if item = invalid then return

    title = item.title
    position = indexOf(m.savedIds, item.id)
    if position >= 0 then
        m.savedIds.Delete(position)
        m.status.text = "Removed from Saved: " + title
    else if m.savedIds.Count() >= 60 then
        m.status.text = "Saved is full (60 channels). Remove one first."
        return
    else
        m.savedIds.Push(item.id)
        m.status.text = "Saved: " + title
    end if

    writeList("saved", m.savedIds)
    rebuildSaved()
    refreshMenuTitles()
    if shown.isSameNode(m.saved) and m.saved.getChildCount() = 0 then m.menuList.setFocus(true)
end sub

' ---------- search ----------

sub openSearch()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Search channels"
    dialog.buttons = ["Search", "Cancel"]
    dialog.observeField("buttonSelected", "onSearchButton")
    dialog.observeField("wasClosed", "onSearchClosed")
    m.searchTerm = ""
    m.top.dialog = dialog
end sub

sub onSearchButton()
    dialog = m.top.dialog
    if dialog = invalid then return
    if dialog.buttonSelected = 0 then m.searchTerm = dialog.text.Trim()
    dialog.close = true
end sub

sub onSearchClosed()
    if m.searchTerm = "" then
        m.menuList.setFocus(true)
        return
    end if

    term = LCase(m.searchTerm)
    m.results.removeChildrenIndex(m.results.getChildCount(), 0)
    for each category in m.playlist.getChildren(-1, 0)
        for each item in category.getChildren(-1, 0)
            if Instr(1, LCase(item.title), term) > 0 then m.results.appendChild(item.clone(false))
        end for
    end for
    for each item in m.penalty.getChildren(-1, 0)
        if Instr(1, LCase(item.title), term) > 0 then m.results.appendChild(item.clone(false))
    end for

    found = m.results.getChildCount()
    m.channels.content = m.results
    m.status.text = found.ToStr() + " results for " + Chr(34) + m.searchTerm + Chr(34)
    if found > 0 then
        m.channels.setFocus(true)
    else
        m.menuList.setFocus(true)
    end if
end sub

' ---------- remote ----------

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    ' While a channel plays full screen the Video node keeps every key except OK, Back,
    ' Up and Down. Back always goes to the list (a break carries on in the window), so
    ' OK is the way back to the show during a break.
    if m.fullScreen then
        if key = "back" then
            showPreview()
            return true
        end if
        if key = "OK" and m.onBreak then
            leaveBreak(true)
            return true
        end if
        if key = "up" or key = "down" then
            delta = 1
            if key = "up" then delta = -1
            shown = m.channels.content
            target = m.playIndex + delta
            if shown <> invalid and target >= 0 and target < shown.getChildCount() then playChannel(target)
            return true
        end if
        return false
    end if

    if not m.loaded then return false

    if m.menuList.isInFocusChain() then
        if key = "right" then
            focusChannels()
            return true
        end if
        ' The first Back on the menu stops the channel in the window; the next one leaves the app.
        if key = "back" and m.playing then
            m.status.text = "Stopped " + m.main.title
            stopVideo()
            return true
        end if
    else if m.channels.isInFocusChain() then
        if key = "left" or key = "back" then
            m.menuList.setFocus(true)
            return true
        end if
        if key = "options" then
            toggleSaved()
            return true
        end if
        if key = "play" then
            setBreakChannel()
            return true
        end if
    end if

    return false
end function
