local aimbot = {}
local user_input_service
local run_service
local players
local camera = cloneref(workspace.CurrentCamera)

local screen_middle = camera.ViewportSize / 2
local viewport_connection

local vec_up = Vector3.new(0, 1, 0)
local visibility_params = nil
local teamHighlightCache = {}
local lastCacheUpdate = 0
local CACHE_UPDATE_INTERVAL = 0.5

local function get_visibility_params()
    if visibility_params then return visibility_params end
    visibility_params = RaycastParams.new()
    visibility_params.FilterType = Enum.RaycastFilterType.Exclude
    local viewmodelsFolder = workspace:FindFirstChild("Viewmodels")
    local ignore = {camera}
    if viewmodelsFolder then
        local localVM = viewmodelsFolder:FindFirstChild("LocalViewmodel")
        if localVM then ignore[2] = localVM end
    end
    visibility_params.FilterDescendantsInstances = ignore
    return visibility_params
end

local function updateTeamHighlightCache()
    teamHighlightCache = {}
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Highlight") and obj.Adornee then
            teamHighlightCache[obj.Adornee] = true
        end
    end
end

local function hasTeamHighlight(model)
    if not model then return false end

    local currentTime = tick()
    if currentTime - lastCacheUpdate > CACHE_UPDATE_INTERVAL then
        updateTeamHighlightCache()
        lastCacheUpdate = currentTime
    end

    return teamHighlightCache[model] == true
end

local settings = {
    enabled = false,
    silent = false,
    visibility = false,
    team_check = false,
    circle = Drawing.new("Circle"),
    screen_middle = screen_middle,
    smoothing = 200,
    pressed = "aiming",
    hitbox_priority = {
        "head", "torso", "shoulder1", "shoulder2",
        "arm1", "arm2", "hip1", "hip2", "leg1", "leg2"
    },
    hitbox_offset = Vector3.new(0, 0, 0)
}
local circle_hidden = false
local circle = settings.circle
local function toggle_circle()
    circle_hidden = not circle_hidden
    circle.Visible = not circle_hidden
end

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

local function is_valid_viewmodel(vm)
    if not vm or vm.Name == "LocalViewmodel" then return false end

    local torso = vm:FindFirstChild("torso")
    if torso and torso:IsA("BasePart") and torso.Transparency == 1 then
        return false
    end

    if settings.team_check and hasTeamHighlight(vm) then
        return false
    end

    return true
end

local function find_closest()
    local closestVM, closestScr, closestPart
    local bestDist = math.huge
    local screen_mid = settings.screen_middle
    local viewmodels = workspace:FindFirstChild("Viewmodels")

    if not viewmodels then return nil,nil,nil,nil end

    for _, vm in ipairs(viewmodels:GetChildren()) do
        if not is_valid_viewmodel(vm) then
            continue
        end

        local torso = vm:FindFirstChild("torso")
        if torso and torso:IsA("BasePart") and torso.Transparency == 1 then
            continue
        end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local scrPos, onScreen = to_view_point and to_view_point(aimPos) or camera:WorldToViewportPoint(aimPos)
            if not onScreen then continue end

            local dx = scrPos.X - screen_mid.X
            local dy = scrPos.Y - screen_mid.Y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > settings.circle.Radius then continue end

            if dist < bestDist then
                if settings.visibility then
                    local origin = camera.CFrame.Position
                    local toPart = part.Position - origin
                    local rayResult = workspace:Raycast(origin, toPart.Unit * (toPart.Magnitude + 0.1), get_visibility_params())
                    if not rayResult then continue end
                    local hit = rayResult.Instance
                    if hit ~= part and not hit:IsDescendantOf(vm) then
                        continue
                    end
                end
                bestDist = dist
                closestVM = vm
                closestScr = scrPos
                closestPart = part
            end
        end
    end

    return nil, closestVM, closestScr, closestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service        = get_service("RunService")
    players            = get_service("Players")

    user_input_service.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            toggle_circle()
        end
    end)

    local renderConn
    local function renderStep()
        if not settings.enabled or settings.silent or user_input_service.MouseBehavior == Enum.MouseBehavior.Default or not get_useable() then
            return
        end
        local vm, scr, part = find_closest()
        if not (vm and part) then return end

        local t = tick() * 1000
        local lerp = math.clamp((t % 100000) / settings.smoothing, 0, 1)
        local targetCF = CFrame.lookAt(camera.CFrame.Position, part.Position, vec_up)
        local baseCF = camera.CFrame:Lerp(targetCF, 1 - (1 - lerp) ^ 2)
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
            if vm and part then
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
