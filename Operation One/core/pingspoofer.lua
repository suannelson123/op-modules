local pingspoofer = {}
local settings = {
    mode = "off"  -- "off" | number (seconds, e.g. 0.05 = 50ms) | "inf" | "nan"
}

rawset(pingspoofer, "pingspoofer_settings", settings)

local old_namecall
old_namecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    if checkcaller() then
        return old_namecall(self, ...)
    end

    if getnamecallmethod() == 'GetNetworkPing' then
        local mode = settings.mode
        if mode == "off" then
            return old_namecall(self, ...)
        elseif mode == "inf" then
            return math.huge
        elseif mode == "nan" then
            return 0/0
        elseif type(mode) == "number" then
            return mode
        end
    end

    return old_namecall(self, ...)
end))

return pingspoofer