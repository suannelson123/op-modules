local weapon_modifications = {};
local settings = {
    recoil_x = 1,
    recoil_y = 1,
    no_spread = false,
    fast_reload = false
};

rawset(weapon_modifications, "weapon_modifications_settings", settings);

weapon_modifications.init = function()

    --[[ -- broken
    local old_math_random = clonefunction(math.random);
    hook_function(math.random, newcclosure(function(...)
        if (debug.info(3, 'n') == "send_shoot" and settings.no_spread) then
            setstack(3, 12, 0);
            setstack(3, 5, 0);
        end;
        return old_math_random(...);
    end));
    ]]

    local old_tweenInfo_new = clonefunction(TweenInfo.new);
    hook_function(TweenInfo.new, newcclosure(function(...)
        if (debug.info(3, 'n') == "recoil_function") then
            setstack(3, 5, (debug.getstack(3, 5) * settings.recoil_x));
            setstack(3, 6, (debug.getstack(3, 6) * settings.recoil_y));
       --[[
       --broken rn ill fix later
        elseif (debug.info(4, 'n') == "reload_begin" and typeof(debug.getstack(4, 6)) == "number" and settings.fast_reload) then
            debug.setstack(4, 6, (debug.getstack(4, 6) / 1.1));
       ]]
        end;
        return old_tweenInfo_new(...);
    end));

end;

return weapon_modifications;
