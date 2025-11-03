local weapon_modifications = {};
local settings = {
    recoil_x = 1,
    recoil_y = 1,
    no_spread = false,
    fast_reload = false,
    fast_firerate = false,     
    firerate_multiplier = 2.0  
};

rawset(weapon_modifications, "weapon_modifications_settings", settings);

weapon_modifications.init = function()

    local old_math_random = clonefunction(math.random);
    hook_function(math.random, newcclosure(function(...)
        if (debug.info(3, 'n') == "send_shoot" and settings.no_spread) then
            debug.setstack(3, 13, 0);
        end;
        return old_math_random(...);
    end));

    local old_tweenInfo_new = clonefunction(TweenInfo.new);
    hook_function(TweenInfo.new, newcclosure(function(...)
        local args = {...};
        local caller_name = debug.info(3, 'n');

        if (caller_name == "recoil_function") then
            debug.setstack(3, 5, (debug.getstack(3, 5) * settings.recoil_x));
            debug.setstack(3, 6, (debug.getstack(3, 6) * settings.recoil_y));

        elseif (debug.info(4, 'n') == "reload_begin" and typeof(debug.getstack(4, 6)) == "number" and settings.fast_reload) then
            debug.setstack(4, 6, (debug.getstack(4, 6) / 1.1));

        elseif (caller_name == "fire" or caller_name == "shoot" or caller_name == "send_shoot") and settings.fast_firerate then
            if (typeof(args[1]) == "number" and args[1] > 0) then
                args[1] = args[1] / settings.firerate_multiplier;
                return old_tweenInfo_new(unpack(args));
            end
        end;

        return old_tweenInfo_new(...);
    end));

    local old_task_delay = clonefunction(task.delay);
    hook_function(task.delay, newcclosure(function(delay_time, callback)
        if settings.fast_firerate then
            local caller = debug.info(2, 'n');
            if (caller == "fire" or caller == "shoot" or caller == "primary_fire") and typeof(delay_time) == "number" then
                delay_time = delay_time / settings.firerate_multiplier;
            end
        end
        return old_task_delay(delay_time, callback);
    end));

end;

return weapon_modifications;
