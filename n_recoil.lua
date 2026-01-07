-- recoil modifier Op1
local RecoilAmt = 0.5; --// ok so 1 is regular recoil 0 is none and 0.5 is half i hope you understand it lit math 101
run_on_actor(getactors()[1], string.gsub([==[
    local TweenInfoNew; TweenInfoNew = hookfunction(TweenInfo.new, newcclosure(function(...)
        if (debug.info(3, 'n') == "recoil_function") then
            setstack(3, 5, (getstack(3, 5) * RecoilAmt));
            setstack(3, 6, (getstack(3, 6) * RecoilAmt));
        end;
        return TweenInfoNew(...);
    end));
]==], "RecoilAmt", RecoilAmt));
