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
    circle = nil, 
    screen_middle = (camera and camera.ViewportSize and (camera.ViewportSize / 2)) or Vector2.new(0, 0),
    smoothing = 200,
    pressed = "aiming",
    visibility = false,
    visibility_tolerance = 0,
    hitbox_priority = {
        "leg2", "leg1", "hip2", "hip1", "shoulder2", "shoulder1", "torso", "head"
    },
    hitbox_offset = Vector3.new(0, 0, 0)
}
local screen_middle = settings.screen_middle

settings.circle = nil
pcall(function()
    local c = Drawing.new("Circle")
    if c then
        c.Visible = false
        c.Radius = 120
        c.Filled = false
        c.Thickness = 1
        c.Color = Color3.new(1, 1, 1)
        c.Position = screen_middle
        settings.circle = c
    end
end)
local circle = settings.circle

local aim_indicator = nil
pcall(function()
    local ind = Drawing.new("Circle")
    if ind then
        ind.Visible = false
        ind.Radius = 5
        ind.Filled = true
        ind.Thickness = 1
        ind.NumSides = 16
        ind.Transparency = 1
        ind.Color = Color3.fromRGB(0, 255, 0)
        aim_indicator = ind
    end
end)

local function hideAimIndicator()
    if aim_indicator then
        pcall(function() aim_indicator.Visible = false end)
    end
end

local function showAimIndicator(posVec2)
    if aim_indicator and posVec2 then
        pcall(function()
            aim_indicator.Position = posVec2
            aim_indicator.Color = Color3.fromRGB(0, 255, 0)
            aim_indicator.Visible = true
        end)
    end
end

local function get_useable()
    return (
        settings.pressed == "None" and true
        or settings.pressed == "shooting" and user_input_service and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or settings.pressed == "aiming" and user_input_service and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        or settings.pressed == "any" and user_input_service and (
            user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        )
    ) or false
end

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end
    if not players then return false end
    local origin = camera.CFrame.Position
    local direction = (point - origin)
    if direction.Magnitude <= 0 then return true end
    local params = RaycastParams.new()
    local filters = {}
    if players.LocalPlayer and players.LocalPlayer.Character then
        table.insert(filters, players.LocalPlayer.Character)
    end
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = filters
    local currentOrigin = origin
    local remainingDir = point - currentOrigin
    local attempts = 0
    local maxAttempts = 5
    local advanceOffset = 0.05
    while attempts < maxAttempts do
        local result = workspace:Raycast(currentOrigin, remainingDir, params)
        if not result then return true end
        local hit = result.Instance
        if not hit then return true end
        if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
            return true
        end
        if hit:IsA("BasePart") then
            local transparentEnough = (hit.Transparency >= settings.visibility_tolerance)
            local canCollide = hit.CanCollide
            if transparentEnough or (canCollide == false) then
                local unitRem = remainingDir.Unit
                currentOrigin = result.Position + (unitRem * advanceOffset)
                remainingDir = point - currentOrigin
                if remainingDir.Magnitude <= 0 then return true end
                attempts = attempts + 1
            else
                return false
            end
        else
            local unitRem = remainingDir.Unit
            currentOrigin = result.Position + (unitRem * advanceOffset)
            remainingDir = point - currentOrigin
            if remainingDir.Magnitude <= 0 then return true end
            attempts = attempts + 1
        end
    end
    return false
end

local viewmodels_folder = workspace:FindFirstChild("Viewmodels")
local cached_players = {}
local target_cache = nil
local last_find = 0
local FIND_RATE = 0.033

task.spawn(function()
    while task.wait(0.5) do
        if players then
            cached_players = players:GetPlayers()
        end
    end
end)

local function find_closest()
    local now = tick()
    if now - last_find < FIND_RATE then
        return unpack(target_cache or {nil, nil, nil, nil})
    end
    last_find = now

    local best_dist = math.huge
    local best = {nil, nil, nil, nil}
    local screen_mid = settings.screen_middle or screen_middle

    hideAimIndicator()

    for _, pl in ipairs(cached_players) do
        if pl == players.LocalPlayer then continue end
        local vm = viewmodels_folder and (viewmodels_folder:FindFirstChild(pl.Name))
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then continue end

            local visibleCheck = is_visible(aimPos, vm)
            if visibleCheck and point and point.X and point.Y then
                showAimIndicator(point)
            end

            if settings.visibility and not visibleCheck then continue end

            local screenDist = (point - screen_mid).Magnitude
            if circle and circle.Visible and screenDist > circle.Radius then continue end

            if screenDist < best_dist then
                best_dist = screenDist
                best = {pl, vm, point, part}
                break
            end
        end
    end

    if not best[1] then hideAimIndicator() end
    target_cache = best
    return unpack(best)
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service = get_service("RunService")
    players = get_service("Players")

    task.spawn(function()
        while task.wait(FIND_RATE) do
            if settings.enabled and get_useable() and not settings.silent then
                find_closest()
            end
        end
    end)

    on_esp_ran(function()
        local player, closest, screen_pos, aim_part = unpack(target_cache or {nil, nil, nil, nil})
        if not (player and closest and aim_part) then
            hideAimIndicator()
            return
        end

        if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
            or not get_useable()
            or not settings.enabled
            or settings.silent then
            start = 0
            rot = Vector2.new()
            return
        end

        start = start + (run_service.RenderStepped:Wait() * 1000)
        local lerp = math.clamp(start / settings.smoothing, 0, 1)
        local base_cframe = camera.CFrame:Lerp(
            CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0)),
            (1 - (1 - lerp) ^ 2)
        )
        rot = rot + (user_input_service:GetMouseDelta() * 0.0005)
        camera.CFrame = base_cframe * CFrame.Angles(0, -rot.X, 0) * CFrame.Angles(-rot.Y, 0, 0)

        if lerp >= 1 then
            start = 0
            rot = Vector2.new()
        end
    end)

    local old_cframe_new = clonefunction(CFrame.new)
    hook_function(CFrame.new, function(...)
        if debug.info(3, 'n') == "send_shoot"
            and settings.enabled
            and settings.silent
            and get_useable() then

            local player, closest, screen_pos, aim_part = unpack(target_cache or {nil, nil, nil, nil})
            if player and closest and aim_part then
                local vis = is_visible(aim_part.Position, closest)
                if vis and screen_pos then
                    pcall(function() showAimIndicator(screen_pos) end)
                else
                    hideAimIndicator()
                end
                debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3, 3).Position, aim_part.Position))
            else
                hideAimIndicator()
            end
        end
        return old_cframe_new(...)
    end)
end

return aimbot
