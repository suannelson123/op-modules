local aimbot = {}
local user_input_service
local run_service
local players
local camera = cloneref(workspace.CurrentCamera)

local screen_middle = camera.ViewportSize / 2
local viewport_connection

local settings = {
    enabled = false,
    silent = false,
    circle = Drawing.new("Circle"),
    screen_middle = screen_middle,
    smoothing = 200,
    pressed = "aiming",
    visibility = false,
    visibility_tolerance = 0.2,
    hitbox_priority = {
        "head", "torso", "shoulder1", "shoulder2",
        "arm1", "arm2", "hip1", "hip2", "leg1", "leg2"
    },
    hitbox_offset = Vector3.new(0, 0, 0)
}

local circle = settings.circle

pcall(function()
    circle.Visible = false
    circle.Radius = 120
    circle.Filled = false
    circle.Thickness = 1
    circle.Color = Color3.new(1, 1, 1)
    circle.Position = screen_middle
end)

-- Aim indicator
local aim_indicator = nil
pcall(function()
    aim_indicator = Drawing.new("Circle")
    aim_indicator.Visible = false
    aim_indicator.Radius = 5
    aim_indicator.Filled = true
    aim_indicator.Thickness = 1
    aim_indicator.NumSides = 16
    aim_indicator.Transparency = 1
    aim_indicator.Color = Color3.fromRGB(0, 255, 0)
end)

local function to_view_point(world_pos)
    local screen_pos, on_screen = camera:WorldToViewportPoint(world_pos)
    return Vector2.new(screen_pos.X, screen_pos.Y), on_screen
end

local function update_screen_middle()
    screen_middle = camera.ViewportSize / 2
    settings.screen_middle = screen_middle
    pcall(function()
        if circle.Visible then
            circle.Position = screen_middle
        end
        if aim_indicator and aim_indicator.Visible then
        end
    end)
end

if viewport_connection then viewport_connection:Disconnect() end
viewport_connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update_screen_middle)

update_screen_middle()

local function hideAimIndicator()
    if not aim_indicator then return end
    pcall(function() aim_indicator.Visible = false end)
end

local function showAimIndicator(posVec2)
    if not aim_indicator then return end
    pcall(function()
        aim_indicator.Position = posVec2
        aim_indicator.Color = Color3.fromRGB(0, 255, 0)
        aim_indicator.Visible = true
    end)
end

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
    local distance = direction.Magnitude
    if distance <= 0 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {}

    if players and players.LocalPlayer and players.LocalPlayer.Character then
        table.insert(params.FilterDescendantsInstances, players.LocalPlayer.Character)
    end

    local currentOrigin = origin
    local remaining = direction.Unit * distance
    local attempts = 0
    local maxAttempts = 15
    local eps = 0.05

    while attempts < maxAttempts do
        local result = workspace:Raycast(currentOrigin, remaining, params)
        if not result then
            return true
        end
        local hit = result.Instance
        if not hit then return true end

        if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
            return true
        end

        local skipHit = false
        if not hit.CanCollide then
            skipHit = true
        elseif hit.Transparency > settings.visibility_tolerance then
            skipHit = true
        end

        if skipHit then
            local hitPos = result.Position
            currentOrigin = hitPos + remaining.Unit * eps
            remaining = (point - currentOrigin)
            if remaining.Magnitude <= 0.01 then return true end
            attempts += 1
        else
            return false
        end
    end
    return false
end

local function find_closest()
    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance = math.huge
    local screen_mid = settings.screen_middle
    local viewmodels_folder = workspace:FindFirstChild("Viewmodels")

    hideAimIndicator()

    for _, pl in ipairs(PlayerAmt) do
        if pl == players.LocalPlayer then continue end

        local vm
        if viewmodels_folder then
            vm = viewmodels_folder:FindFirstChild(pl.Name)
                or viewmodels_folder:FindFirstChild("Viewmodels/" .. pl.Name)
        end
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then continue end

            local visibleCheck = is_visible(aimPos, vm)
            if visibleCheck then
                showAimIndicator(point)
            end

            if settings.visibility and not visibleCheck then
                continue
            end

            local screenDist = (point - screen_mid).Magnitude
            if settings.circle.Visible and screenDist > settings.circle.Radius then
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

    if not ClosestPlayer then
        hideAimIndicator()
    end

    return ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service = get_service("RunService")
    players = get_service("Players")

    local render_connection
    if typeof(on_esp_ran) == "function" then
        on_esp_ran(function()
            local player, closest, screen_pos, aim_part = find_closest()
            if not (player and closest and aim_part) then return end

            if is_visible(aim_part.Position, closest) and screen_pos then
                showAimIndicator(screen_pos)
            else
                hideAimIndicator()
            end

            if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
                or not get_useable()
                or not settings.enabled
                or settings.silent then
                return
            end

            local delta = run_service.RenderStepped:Wait() * 1000
            local start = (tick() * 1000) % 100000
            local lerp = math.clamp(start / settings.smoothing, 0, 1)

            local target_cframe = CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0))
            local base_cframe = camera.CFrame:Lerp(target_cframe, (1 - (1 - lerp) ^ 2))

            local mouse_delta = user_input_service:GetMouseDelta() * 0.0005
            camera.CFrame = base_cframe * CFrame.Angles(0, -mouse_delta.X, 0) * CFrame.Angles(-mouse_delta.Y, 0, 0)
        end)
    else
        render_connection = run_service.RenderStepped:Connect(function()
            local player, closest, screen_pos, aim_part = find_closest()
            if not (player and closest and aim_part) then return end

            if is_visible(aim_part.Position, closest) and screen_pos then
                showAimIndicator(screen_pos)
            else
                hideAimIndicator()
            end

            if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
                or not get_useable()
                or not settings.enabled
                or settings.silent then
                return
            end

            local delta = run_service.RenderStepped:Wait() * 1000
            local start = (tick() * 1000) % 100000
            local lerp = math.clamp(start / settings.smoothing, 0, 1)

            local target_cframe = CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0))
            local base_cframe = camera.CFrame:Lerp(target_cframe, (1 - (1 - lerp) ^ 2))

            local mouse_delta = user_input_service:GetMouseDelta() * 0.0005
            camera.CFrame = base_cframe * CFrame.Angles(0, -mouse_delta.X, 0) * CFrame.Angles(-mouse_delta.Y, 0, 0)
        end)
    end

    local old_cframe_new = clonefunction(CFrame.new)
    hook_function(CFrame.new, function(...)
        local args = {...}
        if debug.info(3, 'n') == "send_shoot"
            and settings.enabled
            and settings.silent
            and get_useable() then

            local player, closest, screen_pos, aim_part = find_closest()
            if player and closest and aim_part then
                if is_visible(aim_part.Position, closest) and screen_pos then
                    pcall(function() showAimIndicator(screen_pos) end)
                else
                    hideAimIndicator()
                end
                local origin = debug.getstack(3, 3)
                if origin and origin.Position then
                    debug.setstack(3, 6, CFrame.lookAt(origin.Position, aim_part.Position))
                end
            else
                hideAimIndicator()
            end
        end
        return old_cframe_new(...)
    end)

    task.spawn(function()
        while task.wait(1) do
            if not getgcobj then break end
        end
    end)
end

return aimbot
