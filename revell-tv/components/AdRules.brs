' Shared by the scene and the ad watcher.

' Some providers (Pluto TV) give their ad segments tell-tale addresses.
function adLikeUrl(url as string) as boolean
    lower = LCase(url)
    if Instr(1, lower, "creative") > 0 then return true
    if Instr(1, lower, "adbumper") > 0 then return true
    if Instr(1, lower, "ad_bumper") > 0 then return true
    if Instr(1, lower, "_ad%2f") > 0 then return true
    if Instr(1, lower, "_ad/") > 0 then return true
    return false
end function
