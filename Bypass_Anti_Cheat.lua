--[[
Before using:

Make sure the executor you're trying to use has setfflag support.
Add the following to your autoexec:

setfflag("DebugRunParallelLuaOnMainThread", "True")
]]

local Paths = {
    "ReplicatedStorage.Modules.Items.Item.Gun.Automatic.MP7.Animations.Reload";
    "ReplicatedStorage.Modules.Items.Item.Utility.Crowbar.Animations.TakeDown";
    "ReplicatedStorage.Modules.Items.Item.Gun.Semi.Shotgun.SPAS12.Animations.Reload";
    "ReplicatedStorage.Modules.Items.Item.Gun.Semi.Shotgun.SPAS12.Animations.Equip";
    "ReplicatedStorage.Modules.Items.Item.Gun.Semi.Shotgun.AA12.Animations.Equip";
    "ReplicatedStorage.Modules.Items.Item.Gun.Semi.DMR.M24.Animations.Reload";
    "ReplicatedStorage.Modules.Items.Item.Gun.Automatic.P90.Animations.Reload";
    "ReplicatedStorage.Modules.Items.Item.Utility.ReinforceItem.Animations.Place";
};

for _, Thread in pairs(getgc(true)) do
    if typeof(Thread) == "thread" then
        local Source = debug.info(Thread, 1, "s");

        if Source and table.find(Paths, Source) then
            coroutine.close(Thread);
        end;
    end;
end;
