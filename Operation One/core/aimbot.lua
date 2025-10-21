local aimbot = {};
local user_input_service:  UserInputService;
local run_service:         RunService;
local players:             Players;
local camera:              Camera = cloneref(workspace.CurrentCamera);
local start = 0;
local rot = Vector2.new();

local settings = {
    enabled = false,
    silent = false,
    circle = Drawing.new("Circle"),
    screen_middle = (camera.ViewportSize / 2),
    target = "head",               -- legacy: used when mode = "classic"
    smoothing = 200,
    pressed = "aiming",

    -- NEW:
    mode = "closest",              -- "classic" = use `target` (head/torso), "closest" = pick closest part to FOV
    hitbox_priority = {"head","torso","shoulder1","shoulder2","arm1","arm2","hip1","hip2","leg1","leg2"},
    hitbox_offset = Vector3.new(0,0,0) -- world-space bias; e.g. Vector3.new(0,0.1,0) if you want slightly above
};


local screen_middle = settings.screen_middle;

local circle = settings.circle do
    circle.Visible = false;
    circle.Radius = 120;
    circle.Filled = false;
    circle.Thickness = 1;
    circle.Color = Color3.new(1, 1, 1);
    circle.Position = screen_middle;
end;

local get_useable = function()
    return (
       settings.pressed == "None"     and true
    or settings.pressed == "shooting" and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and true
    or settings.pressed == "aiming"   and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and true
    or settings.pressed == "any"      and (user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) and true) or false;
end;

local function find_closest()
    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance = math.huge
    local screen_mid = settings.screen_middle or screen_middle

    for i = 2, #PlayerAmt do
        local pl = PlayerAmt[i]
        local vm = workspace.Viewmodels:FindFirstChild("Viewmodels/" .. pl.Name)
        if (not vm) then continue end
        if (not vm:FindFirstChild("EnemyHighlight")) then continue end

        -- If user chose "classic" (head/torso), only check the chosen target part
        if settings.mode == "classic" then
            local partName = settings.target or "head"
            local part = vm:FindFirstChild(partName)
            if not part then continue end
            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then continue end
            local screenDist = (point - screen_mid).Magnitude
            if (settings.circle and settings.circle.Visible and screenDist > settings.circle.Radius) then
                continue
            end
            if screenDist < BestDistance then
                BestDistance = screenDist
                ClosestPlayer = pl
                ClosestViewmodel = vm
                ClosestScreenPos = point
                ClosestPart = part
            end

        -- "closest" mode: iterate priority list and pick the single closest part across ALL players
        else -- settings.mode == "closest"
            for _, partName in ipairs(settings.hitbox_priority) do
                local part = vm:FindFirstChild(partName)
                if not part then goto continue_part end

                local aimPos = part.Position + settings.hitbox_offset
                local point, onScreen = to_view_point(aimPos)
                if not onScreen then goto continue_part end

                local screenDist = (point - screen_mid).Magnitude
                if (settings.circle and settings.circle.Visible and screenDist > settings.circle.Radius) then
                    goto continue_part
                end

                if screenDist < BestDistance then
                    BestDistance = screenDist
                    ClosestPlayer = pl
                    ClosestViewmodel = vm
                    ClosestScreenPos = point
                    ClosestPart = part
                end

                ::continue_part::
            end
        end
    end

    return ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
end


rawset(aimbot, "aimbot_settings", settings);

aimbot.init = function()
    user_input_service = get_service("UserInputService");
    run_service = get_service("RunService");
    players = get_service("Players");

    on_esp_ran(function(has_esp: table, point: Vector2)
        local player, closest, screen_pos, aim_part = find_closest();
        if (not (player and closest)) then return end;

        if (user_input_service.MouseBehavior == Enum.MouseBehavior.Default or not get_useable() or not settings.enabled or settings.silent) then
            start = 0;
            rot = Vector2.new();
            return;
        end;

        start += (run_service.RenderStepped:Wait() * 1000);
        local lerp = math.clamp(start / settings.smoothing, 0, 1);
        local base_cfrmae = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, aim_part.CFrame.Position, Vector3.new(0, 1, 0)), (1 - (1 - lerp) ^ 2));
        rot += (user_input_service:GetMouseDelta() * 0.0005);

        camera.CFrame = base_cfrmae * CFrame.Angles(0, -rot.X, 0) * CFrame.Angles(-rot.Y, 0, 0);

        if (lerp >= 1) then
            start = 0;
            rot = Vector2.new();
            return;
        end;
    end);

    local old_cframe_new = clonefunction(CFrame.new);
    hook_function(CFrame.new, function(...)
        if (debug.info(3, 'n') == "send_shoot" and settings.enabled and settings.silent and get_useable()) then
            local player, closest, screen_pos, aim_part = find_closest();
            if (player and closest) then
                debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3, 3).Position, aim_part.Position));
            end;
        end;
        return old_cframe_new(...);
    end);

end;

return aimbot;
