local aimbot = {}
local user_input_service
local run_service
local players
local camera = cloneref(workspace.CurrentCamera)
local start = 0
local rot = Vector2.new()

local settings = {
    enabled = false,
    silent = false,
    circle = Drawing.new("Circle"),
    screen_middle = (camera.ViewportSize / 2),
    smoothing = 200,
    pressed = "aiming",

    visibility = true,
    visibility_tolerance = 1,

    hitbox_priority = {"head","torso","shoulder1","shoulder2","arm1","arm2","hip1","hip2","leg1","leg2"},
    hitbox_offset = Vector3.new(0,0,0)
}

local screen_middle = settings.screen_middle

local circle = settings.circle
circle.Visible = false
circle.Radius = 120
circle.Filled = false
circle.Thickness = 1
circle.Color = Color3.new(1, 1, 1)
circle.Position = screen_middle

local function get_useable()
    return (
        settings.pressed == "None" and true
        or settings.pressed == "shooting" and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or settings.pressed == "aiming" and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        or settings.pressed == "any" and (
            user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        )
    ) or false
end

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end

    local origin = camera.CFrame.Position
    local direction = (point - origin)
    if direction.Magnitude <= 0 then return true end

    local params = RaycastParams.new()
    local filters = {}
    if players and players.LocalPlayer and players.LocalPlayer.Character then
        table.insert(filters, players.LocalPlayer.Character)
    end
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = filters

    local maxDistance = direction.Magnitude
    local remainingDir = direction.Unit * maxDistance
    local currentOrigin = origin
    local attempts = 0
    while attempts < 5 do
        local result = workspace:Raycast(currentOrigin, remainingDir, params)
        if not result then
            return true
        end

        local hit = result.Instance
        if not hit then
            return true
        end

        if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
            return true
        end

        if hit.Transparency < settings.visibility_tolerance or not hit.CanCollide then
            currentOrigin = result.Position + (remainingDir.Unit * 0.05)
            remainingDir = direction - (currentOrigin - origin)
            attempts += 1
            continue
        end

        return false
    end

    return false
end

local function find_closest()
    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance = math.huge
    local screen_mid = settings.screen_middle or screen_middle
    local viewmodels_folder = workspace:FindFirstChild("Viewmodels")

    for _, pl in ipairs(PlayerAmt) do
        if pl == players.LocalPlayer then continue end

        local vm
        if viewmodels_folder then
            vm = viewmodels_folder:FindFirstChild(pl.Name) or viewmodels_folder:FindFirstChild("Viewmodels/" .. pl.Name)
        end
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then continue end

            if settings.visibility and not is_visible(aimPos, vm) then
                continue
            end

            local screenDist = (point - screen_mid).Magnitude
            if settings.circle and settings.circle.Visible and screenDist > settings.circle.Radius then
                continue
            end

            if screenDist < BestDistance then
                BestDistance = screenDist
                ClosestPlayer = pl
                ClosestViewmodel = vm
                ClosestScreenPos = point
                ClosestPart = part
            end
        end
    end

    return ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service = get_service("RunService")
    players = get_service("Players")

    on_esp_ran(function()
        local player, closest, screen_pos, aim_part = find_closest()
        if not (player and closest and aim_part) then return end

        if user_input_service.MouseBehavior == Enum.MouseBehavior.Default or not get_useable() or not settings.enabled or settings.silent then
            start = 0
            rot = Vector2.new()
            return
        end

        start += (run_service.RenderStepped:Wait() * 1000)
        local lerp = math.clamp(start / settings.smoothing, 0, 1)
        local base_cframe = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0)), (1 - (1 - lerp) ^ 2))
        rot += (user_input_service:GetMouseDelta() * 0.0005)
        camera.CFrame = base_cframe * CFrame.Angles(0, -rot.X, 0) * CFrame.Angles(-rot.Y, 0, 0)

        if lerp >= 1 then
            start = 0
            rot = Vector2.new()
            return
        end
    end)

    local old_cframe_new = clonefunction(CFrame.new)
  hook_function(CFrame.new, function(...)
    if debug.info(3, 'n') == "send_shoot" then
        local player, closest, screen_pos, aim_part = find_closest()
        if not (player and closest and aim_part) then
            warn("[SilentAim] No valid target found (visibility likely failed)")
        else
            print("[SilentAim] Target:", closest.Name, "Part:", aim_part.Name)
            debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3, 3).Position, aim_part.Position))
        end
    end
    return old_cframe_new(...)
end)

end

return aimbot
