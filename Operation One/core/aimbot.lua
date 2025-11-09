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
    screen_middle = Vector2.new(0, 0),
    smoothing = 200,
    pressed = "aiming",
    visibility = false,
    visibility_tolerance = 0,

    hitbox_priority = {
        "head", "torso", "shoulder1", "shoulder2",
        "arm1", "arm2", "hip1", "hip2", "leg1", "leg2"
    },
    hitbox_offset = Vector3.new(0, 0, 0)
}

local circle = settings.circle
circle.Visible = false
circle.Radius = 120
circle.Filled = false
circle.Thickness = 1
circle.Color = Color3.new(1, 1, 1)

local aim_indicator = Drawing.new("Circle")
aim_indicator.Visible = false
aim_indicator.Radius = 5
aim_indicator.Filled = true
aim_indicator.Thickness = 1
aim_indicator.NumSides = 16
aim_indicator.Transparency = 1
aim_indicator.Color = Color3.fromRGB(0, 255, 0)

local hideAimIndicator = function()
    if aim_indicator.Visible then
        aim_indicator.Visible = false
    end
end

local showAimIndicator = function(posVec2)
    aim_indicator.Position = posVec2
    aim_indicator.Visible = true
end

local function get_useable()
    local pressed = settings.pressed
    if pressed == "None" then return true end
    if pressed == "shooting" then
        return user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif pressed == "aiming" then
        return user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif pressed == "any" then
        return user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or user_input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    return false
end

local function update_screen_middle()
    local viewport = camera.ViewportSize
    local new_middle = viewport / 2
    if new_middle ~= settings.screen_middle then
        settings.screen_middle = new_middle
        circle.Position = new_middle
    end
end

local ray_params = RaycastParams.new()
ray_params.FilterType = Enum.RaycastFilterType.Blacklist
local filters = {}

local function is_visible(point, targetModel)
    if not camera then return false end
    local origin = camera.CFrame.Position
    local direction = point - origin
    if direction.Magnitude <= 0 then return true end

    table.clear(filters)
    local localChar = players.LocalPlayer and players.LocalPlayer.Character
    if localChar then table.insert(filters, localChar) end

    local vmFolder = workspace:FindFirstChild("Viewmodels")
    if vmFolder then
        local localVm = vmFolder:FindFirstChild("Viewmodels/" .. (players.LocalPlayer and players.LocalPlayer.Name or ""))
        if localVm then table.insert(filters, localVm) end
    end

    ray_params.FilterDescendantsInstances = filters

    local result = workspace:Raycast(origin, direction, ray_params)
    if not result then return true end

    local hit = result.Instance
    if not hit then return true end
    if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
        return true
    end

    if hit.Transparency >= settings.visibility_tolerance or not hit.CanCollide then
        return true
    end

    return false
end

local function to_screen_point(pos)
    local screenPos, onScreen = camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function find_closest()
    local playerList = players:GetPlayers()
    local bestPart, bestPlayer, bestViewmodel, bestScreenPos
    local bestDist = math.huge
    local screen_mid = settings.screen_middle
    local viewmodels_folder = workspace:FindFirstChild("Viewmodels")

    for i = 1, #playerList do
        local pl = playerList[i]
        if pl == players.LocalPlayer then continue end

        local vm = viewmodels_folder and (viewmodels_folder:FindFirstChild(pl.Name)
            or viewmodels_folder:FindFirstChild("Viewmodels/" .. pl.Name))
        if not (vm and vm:FindFirstChild("EnemyHighlight")) then continue end

        for j = 1, #settings.hitbox_priority do
            local part = vm:FindFirstChild(settings.hitbox_priority[j])
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_screen_point(aimPos)
            if not onScreen then continue end

            local dist = (point - screen_mid).Magnitude
            if circle.Visible and dist > circle.Radius then continue end
            if dist < bestDist then
                bestDist = dist
                bestPlayer, bestViewmodel, bestScreenPos, bestPart =
                    pl, vm, point, part
            end
        end
    end

    return bestPlayer, bestViewmodel, bestScreenPos, bestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service = get_service("RunService")
    players = get_service("Players")

    run_service.RenderStepped:Connect(update_screen_middle)

    on_esp_ran(function()
        if not settings.enabled then
            hideAimIndicator()
            return
        end

        local player, viewmodel, screen_pos, part = find_closest()
        if not (player and viewmodel and part) then
            hideAimIndicator()
            return
        end

        local visible = true
        if settings.visibility then
            visible = is_visible(part.Position, viewmodel)
        end

        if visible then
            showAimIndicator(screen_pos)
        else
            hideAimIndicator()
        end

        if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
            or not get_useable()
            or settings.silent then
            start = 0
            rot = Vector2.new()
            return
        end

        start += (run_service.RenderStepped:Wait() * 1000)
        local lerp = math.clamp(start / settings.smoothing, 0, 1)
        local targetCFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, (1 - (1 - lerp)^2))
            * CFrame.Angles(-rot.Y, -rot.X, 0)

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

            local player, viewmodel, screen_pos, part = find_closest()
            if player and viewmodel and part then
                local visible = not settings.visibility or is_visible(part.Position, viewmodel)
                if visible then
                    showAimIndicator(screen_pos)
                    debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3, 3).Position, part.Position))
                else
                    hideAimIndicator()
                end
            else
                hideAimIndicator()
            end
        end
        return old_cframe_new(...)
    end)
end

return aimbot
