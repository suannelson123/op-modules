local weapon_modifications = {}
local settings = {
    recoil_x = 1,
    recoil_y = 1,
    no_spread = true,
    fast_reload = false
}

rawset(weapon_modifications, "weapon_modifications_settings", settings)

weapon_modifications.init = function()

    -- Hook Random.new():NextNumber()
    local old_nextnumber
    old_nextnumber = hookmetamethod(Random.new(), "__index", newcclosure(function(self, key)
        if key == "NextNumber" then
            local old_func = rawget(self, key) or Random.new().NextNumber
            return function(...)
                if settings.no_spread then
                    local caller = debug.info(3, "n")
                    if caller and (caller:lower():find("shoot") or caller:lower():find("fire")) then
                        -- Neutralize spread
                        return 0
                    end
                end
                return old_func(...)
            end
        end
        return old_nextnumber(self, key)
    end))

    -- Hook recoil + reload as before
    local old_tweenInfo_new = clonefunction(TweenInfo.new)
    hook_function(TweenInfo.new, newcclosure(function(...)
        if (debug.info(3, 'n') == "recoil_function") then
            debug.setstack(3, 5, (debug.getstack(3, 5) * settings.recoil_x))
            debug.setstack(3, 6, (debug.getstack(3, 6) * settings.recoil_y))
        elseif (debug.info(4, 'n') == "reload_begin" and typeof(debug.getstack(4, 6)) == "number" and settings.fast_reload) then
            debug.setstack(4, 6, (debug.getstack(4, 6) / 1.1))
        end
        return old_tweenInfo_new(...)
    end))

end

return weapon_modifications
