local aimbot = {}
local user_input_service
local run_service
local players
local camera = workspace.CurrentCamera
local start = 0
local rot = Vector2.new()

local settings = {
    enabled = false,
    silent = false,
    circle = nil,
    screen_middle = Vector2.new(0,0),
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

local ok, newCircle = pcall(function() return Drawing.new("Circle") end)
if ok and newCircle then
    settings.circle = newCircle
    local circle = settings.circle
    pcall(function()
        circle.Visible = false
        circle.Radius = 120
        circle.Filled = false
        circle.Thickness = 1
        circle.Color = Color3.new(1, 1, 1)
    end)
end

local circle = settings.circle

local aim_indicator = nil
local ok2, newAim = pcall(function() return Drawing.new("Circle") end)
if ok2 and newAim then
    aim_indicator = newAim
    pcall(function()
        aim_indicator.Visible = false
        aim_indicator.Radius = 5
        aim_indicator.Filled = true
        aim_indicator.Thickness = 1
        aim_indicator.NumSides = 16
        aim_indicator.Transparency = 1
        aim_indicator.Color = Color3.fromRGB(0, 255, 0)
    end)
end

local function hideAimIndicator()
    if aim_indicator then pcall(function() aim_indicator.Visible = false end) end
end

local function showAimIndicator(posVec2)
    if aim_indicator then
        pcall(function()
            aim_indicator.Position = posVec2
            aim_indicator.Visible = true
        end)
    end
end

local function get_useable()
    if not user_input_service then return false end
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

local function update_screen_middle()
    if camera and camera.ViewportSize then
        settings.screen_middle = camera.ViewportSize / 2
        if circle then
            pcall(function() circle.Position = settings.screen_middle end)
        end
    end
end

local function to_view_point(worldPos)
    if not camera or not camera.WorldToViewportPoint then
        return Vector2.new(0,0), false
    end
    local ok, resX, resY, resZ = pcall(function()
        local vec3 = camera:WorldToViewportPoint(worldPos)
        return vec3.X, vec3.Y, vec3.Z
    end)
    if not ok or not resX then
        return Vector2.new(0,0), false
    end
    return Vector2.new(resX, resY), (resZ > 0)
end

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end

    local origin = camera.CFrame.Position
    local direction = (point - origin)
    if direction.Magnitude <= 0 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local filters = {}

    if players and players.LocalPlayer and players.LocalPlayer.Character then
        table.insert(filters, players.LocalPlayer.Character)
    end

    local vmFolder = workspace:FindFirstChild("Viewmodels")
    if vmFolder and players and players.LocalPlayer then
        local localVm = vmFolder:FindFirstChild(players.LocalPlayer.Name)
        if localVm then table.insert(filters, localVm) end
    end

    params.FilterDescendantsInstances = filters

    local ok, result = pcall(function()
        return workspace:Raycast(origin, direction, params)
    end)
    if not ok or not result then return true end

    local hit = result.Instance
    if not hit then return true end

    if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
        return true
    end

    return (hit.Transparency >= settings.visibility_tolerance or not hit.CanCollide)
end

local function find_closest()
    if not players or not players.GetPlayers or not camera then return nil, nil, nil, nil end

    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance = math.huge
    local screen_mid = settings.screen_middle or Vector2.new(0,0)
    local viewmodels_folder = workspace:FindFirstChild("Viewmodels")

    for _, pl in ipairs(PlayerAmt) do
        if pl == players.LocalPlayer then goto continue_player end

        local vm
        if viewmodels_folder then
            vm = viewmodels_folder:FindFirstChild(pl.Name)
        end
        if not vm or not vm:FindFirstChild("EnemyHighlight") then goto continue_player end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then goto continue_part end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then goto continue_part end

            if circle and circle.Visible and (point - screen_mid).Magnitude > circle.Radius then
                goto continue_part
            end

            local screenDist = (point - screen_mid).Magnitude
            if screenDist < BestDistance then
                BestDistance = screenDist
                ClosestPlayer = pl
                ClosestViewmodel = vm
                ClosestScreenPos = point
                ClosestPart = part
            end

            ::continue_part::
        end

        ::continue_player::
    end

    return ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = game:GetService("UserInputService")
    run_service = game:GetService("RunService")
    players = game:GetService("Players")
    camera = workspace.CurrentCamera

    run_service.RenderStepped:Connect(update_screen_middle)

    run_service.RenderStepped:Connect(function()
        local player, closest, screen_pos, aim_part = find_closest()
        if not (player and closest and aim_part) then
            hideAimIndicator()
            return
        end

        local isVisible = true
        if settings.visibility then
            isVisible = is_visible(aim_part.Position, closest)
        end

        if isVisible and screen_pos then
            showAimIndicator(screen_pos)
        else
            hideAimIndicator()
        end
    end)
end

return aimbot
