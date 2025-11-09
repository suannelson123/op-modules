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
    screen_middle = Vector2.new(0,0), 
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
pcall(function()
    circle.Visible = false
    circle.Radius = 120
    circle.Filled = false
    circle.Thickness = 1
    circle.Color = Color3.new(1, 1, 1)
end)

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

local Workspace = workspace
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local math_huge = math.huge
local ipairs_ref = ipairs 
local to_view_point 

local function update_screen_middle()
    if camera and camera.ViewportSize and circle then
        settings.screen_middle = camera.ViewportSize / 2
        circle.Position = settings.screen_middle
    elseif camera and camera.ViewportSize then
        settings.screen_middle = camera.ViewportSize / 2
    end
end

local _filters = {} 
local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end

    local origin = camera.CFrame.Position
    local direction = (point - origin)
    if direction.Magnitude <= 0 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist

    for i = #_filters, 1, -1 do _filters[i] = nil end

    if players and players.LocalPlayer and players.LocalPlayer.Character then
        _filters[#_filters + 1] = players.LocalPlayer.Character
    end

    local vmFolder = Workspace:FindFirstChild("Viewmodels")
    if vmFolder then
        local localVm = vmFolder:FindFirstChild("Viewmodels/" .. (players.LocalPlayer and players.LocalPlayer.Name or ""))
        if localVm then _filters[#_filters + 1] = localVm end
    end

    params.FilterDescendantsInstances = _filters

    local result = Workspace:Raycast(origin, direction, params)
    if not result then return true end

    local hit = result.Instance
    if not hit then return true end

    if targetModel and (hit == targetModel or hit:IsDescendantOf(targetModel)) then
        return true
    end

    local isTransparentEnough = (hit.Transparency >= settings.visibility_tolerance)
    if isTransparentEnough or not hit.CanCollide then
        return true
    end

    return false
end

local function find_closest()
    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance = math_huge
    local screen_mid = settings.screen_middle or Vector2_new(0,0)
    local viewmodels_folder = Workspace:FindFirstChild("Viewmodels")
    local hp = settings.hitbox_priority
    local hpN = #hp
    local circleLocal = settings.circle -- cache once
    local circleVisible = circleLocal and circleLocal.Visible

    local to_view = to_view_point
    local offset = settings.hitbox_offset

    for i = 1, #PlayerAmt do
        local pl = PlayerAmt[i]
        if pl == players.LocalPlayer then
        else
            local vm
            if viewmodels_folder then
                vm = viewmodels_folder:FindFirstChild(pl.Name) or viewmodels_folder:FindFirstChild("Viewmodels/" .. pl.Name)
            end
            if not vm then
            else
                local enemy_highlight = vm:FindFirstChild("EnemyHighlight")
                if not enemy_highlight or not enemy_highlight.Enabled then
                else
                    for j = 1, hpN do
                        local partName = hp[j]
                        local part = vm:FindFirstChild(partName)
                        if part then
                            local aimPos = part.Position + offset
                            local point, onScreen = to_view(aimPos)
                            if onScreen then
                                local screenDist = (point - screen_mid).Magnitude
                                if not (circleVisible and screenDist > circleLocal.Radius) then
                                    if screenDist < BestDistance then
                                        BestDistance = screenDist
                                        ClosestPlayer = pl
                                        ClosestViewmodel = vm
                                        ClosestScreenPos = point
                                        ClosestPart = part
                                    end
                                end
                            end
                        end
                    end
                end
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

    camera = workspace.CurrentCamera or camera
    if camera and camera.ViewportSize then
        settings.screen_middle = camera.ViewportSize / 2
        if circle then pcall(function() circle.Position = settings.screen_middle end) end
    end

    local last_vx, last_vy = 0, 0
    run_service.RenderStepped:Connect(function()
        if not camera then return end
        local vx, vy = camera.ViewportSize.X, camera.ViewportSize.Y
        if vx ~= last_vx or vy ~= last_vy then
            last_vx, last_vy = vx, vy
            settings.screen_middle = Vector2_new(vx/2, vy/2)
            if circle then pcall(function() circle.Position = settings.screen_middle end) end
        end
    end)

    on_esp_ran(function()
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

        if user_input_service.MouseBehavior == Enum.MouseBehavior.Default
            or not get_useable()
            or not settings.enabled
            or settings.silent then
            start = 0
            rot = Vector2.new()
            return
        end

        start += (run_service.RenderStepped:Wait() * 1000)
        local lerp = math.clamp(start / settings.smoothing, 0, 1)
        local base_cframe = camera.CFrame:Lerp(
            CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0,1,0)),
            (1 - (1 - lerp)^2)
        )
        rot += (user_input_service:GetMouseDelta() * 0.0005)
        camera.CFrame = base_cframe * CFrame.Angles(0,-rot.X,0) * CFrame.Angles(-rot.Y,0,0)

        if lerp >= 1 then
            start = 0
            rot = Vector2.new()
            return
        end
    end)

    local old_cframe_new = clonefunction(CFrame.new)
    hook_function(CFrame.new, function(...)
        if debug.info(3,'n') == "send_shoot"
            and settings.enabled
            and settings.silent
            and get_useable() then

            local player, closest, screen_pos, aim_part = find_closest()
            if player and closest and aim_part then
                local isVisible = not settings.visibility or is_visible(aim_part.Position, closest)
                if isVisible and screen_pos then
                    showAimIndicator(screen_pos)
                    debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3,3).Position, aim_part.Position))
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
