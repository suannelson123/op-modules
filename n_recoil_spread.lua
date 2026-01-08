local RecoilAmt = 50; --// this is the percentage of recoil you want, 100% = full recoil, 0% = no recoil
local SpreadAmt = 0; --// this is the percentage of spread you want, 100% = regular spread, 0% = no spread
local FastReload = true;

run_on_actor(getactors()[1], string.gsub([==[
    local TweenInfoNew; TweenInfoNew = hookfunction(TweenInfo.new, newcclosure(function(...)
        if (debug.info(4, 'n') == "reload_begin" and typeof(getstack(4, 6)) == "number" and FastReload) then
            setstack(4, 6, (getstack(4, 6) / 1.1));
        elseif (debug.info(3, 'n') == "recoil_function") then
            setstack(3, 5, (getstack(3, 5) * RecoilAmt));
            setstack(3, 6, (getstack(3, 6) * RecoilAmt));
        end;
        return TweenInfoNew(...);
    end));
    
    local MathRandom; MathRandom = hookfunction(math.random, newcclosure(function(...)
        if (debug.info(3, 'n') == "send_shoot") then
            setstack(3, 13, getstack(3, 13) * SpreadAmt);
        end;
        return MathRandom(...);
    end));
]==], "%w+", {["RecoilAmt"] = RecoilAmt / 100, ["FastReload"] = FastReload, ["SpreadAmt"] = SpreadAmt / 100}));
