' Opens a Pluto session for one channel so the scene can play it (see Pluto.brs).

sub init()
    m.top.functionName = "openSession"
end sub

sub openSession()
    m.top.sessionUrl = plutoSessionUrl(plutoChannelId(m.top.url), m.top.clientId)
    m.top.done = true
end sub
