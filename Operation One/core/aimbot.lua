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
    circle.Color = Color3.new(1,1,1)
    circle.Position = screen_middle
end)





local function update_screen_middle()
    screen_middle = camera.ViewportSize / 2
    settings.screen_middle = screen_middle
    pcall(function()
        if circle.Visible then circle.Position = screen_middle end
    end)
end
if viewport_connection then viewport_connection:Disconnect() end
viewport_connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update_screen_middle)
update_screen_middle()



local function get_useable()
    return (
        settings.pressed == "None" and true
        or settings.pressed == "shooting" and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or settings.pressed == "aiming"  and user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        or settings.pressed == "any"     and (
            user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or
            user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        )
    ) or false
end

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end
    local origin = camera.CFrame.Position
    local dir    = point - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {}

    if players and players.LocalPlayer and players.LocalPlayer.Character then
        table.insert(params.FilterDescendantsInstances, players.LocalPlayer.Character)
    end

    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end                  
    local hit = result.Instance

    if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
        return true
    end

    if not hit.CanCollide or hit.Transparency > settings.visibility_tolerance then
        return true
    end

    return false
end

local function find_closest()
    local closestPl, closestVM, closestScr, closestPart
    local bestDist = math.huge
    local screen_mid = settings.screen_middle
    local viewmodels = workspace:FindFirstChild("Viewmodels")

    for _, pl in ipairs(players:GetPlayers()) do
        if pl == players.LocalPlayer then continue end

        local vm = viewmodels and (viewmodels:FindFirstChild(pl.Name) or viewmodels:FindFirstChild("Viewmodels/"..pl.Name))
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local scrPos, onScreen = to_view_point(aimPos)
            if not onScreen then continue end

            if settings.visibility and not is_visible(aimPos, vm) then continue end

            local dist = (scrPos - screen_mid).Magnitude
            if settings.circle.Visible and dist > settings.circle.Radius then continue end

            if dist < bestDist then
                bestDist = dist
                closestPl   = pl
                closestVM   = vm
                closestScr  = scrPos
                closestPart = part
            end
        end
    end

    return closestPl, closestVM, closestScr, closestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service        = get_service("RunService")
    players            = get_service("Players")

    local renderConn
    local function renderStep()
        local pl, vm, scr, part = find_closest()
        if not (pl and vm and part) then return end

        if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
            or not get_useable() or not settings.enabled or settings.silent then
            return
        end

        local delta = run_service.RenderStepped:Wait() * 1000
        local t = (tick()*1000) % 100000
        local lerp = math.clamp(t / settings.smoothing, 0, 1)

        local targetCF = CFrame.lookAt(camera.CFrame.Position, part.Position, Vector3.new(0,1,0))
        local baseCF   = camera.CFrame:Lerp(targetCF, 1 - (1-lerp)^2)

        local mouseDelta = user_input_service:GetMouseDelta() * 0.0005
        camera.CFrame = baseCF * CFrame.Angles(0, -mouseDelta.X, 0) * CFrame.Angles(-mouseDelta.Y, 0, 0)
    end

    if typeof(on_esp_ran) == "function" then
        on_esp_ran(renderStep)
    else
        renderConn = run_service.RenderStepped:Connect(renderStep)
    end

    local oldCFnew = clonefunction(CFrame.new)
    hook_function(CFrame.new, function(...)
        if debug.info(3,'n') == "send_shoot"
            and settings.enabled and settings.silent and get_useable() then

            local pl, vm, scr, part = find_closest()
            if pl and vm and part then
                local origin = debug.getstack(3,3)
                if origin and origin.Position then
                    debug.setstack(3,6, CFrame.lookAt(origin.Position, part.Position))
                end
            end
        end
        return oldCFnew(...)
    end)
end

return aimbot
