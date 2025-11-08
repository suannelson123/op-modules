local aimbot = {}
local user_input_service
local run_service
local players
local camera = cloneref(workspace.CurrentCamera)
local start = 0
local rot = Vector2.new()

local MAX_VISIBILITY_PASSES = 3      
local VISIBILITY_ADVANCE = 0.06        
local VISIBILITY_DISTANCE_LIMIT = 1000 
local VISIBILITY_CHECK_COOLDOWN = 0.08 

local settings = {
    enabled = false,
    silent = false,
    circle = Drawing.new("Circle"),
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
local circle = settings.circle
do
    pcall(function()
        circle.Visible = false
        circle.Radius = 120
        circle.Filled = false
        circle.Thickness = 1
        circle.Color = Color3.new(1, 1, 1)
        circle.Position = screen_middle
    end)
end

local aim_indicator = nil
do
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
end

local function hideAimIndicator()
    if not aim_indicator then return end
    pcall(function() aim_indicator.Visible = false end)
end

local function showAimIndicator(posVec2)
    if not aim_indicator then return end
    pcall(function()
        aim_indicator.Position = posVec2
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

local raycast_params_cache = nil
local last_visibility_check = {}
local hitbox_priority_cache = table.create(#settings.hitbox_priority)
for i, v in ipairs(settings.hitbox_priority) do hitbox_priority_cache[i] = v end

local function build_raycast_params()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {}
    return params
end

raycast_params_cache = build_raycast_params()

local function dist2(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return dx*dx + dy*dy + dz*dz
end

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end
    if not players then return false end
    if not point then return false end
    if not targetModel then return false end

    local origin = camera.CFrame.Position
    local toTarget = point - origin
    local dist = toTarget.Magnitude
    if dist <= 0 then return true end

    if dist > VISIBILITY_DISTANCE_LIMIT then
        return false -- too far, skip expensive checks
    end

    local now = tick()
    local key = targetModel
    local last = last_visibility_check[key]
    if last and (now - last) < VISIBILITY_CHECK_COOLDOWN then
        if type(last) == "table" and last.time and (now - last.time) < VISIBILITY_CHECK_COOLDOWN then
            return last.result
        end
    end

    local params = raycast_params_cache
    local filters = params.FilterDescendantsInstances
    for i = #filters, 1, -1 do filters[i] = nil end
    if players.LocalPlayer and players.LocalPlayer.Character then
        filters[1] = players.LocalPlayer.Character
    end

    local currentOrigin = origin
    local remainingDir = point - currentOrigin
    local attempts = 0

    while attempts < MAX_VISIBILITY_PASSES do
        local result = workspace:Raycast(currentOrigin, remainingDir, params)
        if not result then
            last_visibility_check[key] = { time = now, result = true }
            return true
        end

        local hit = result.Instance
        if not hit then
            last_visibility_check[key] = { time = now, result = true }
            return true
        end

        if hit == targetModel or hit:IsDescendantOf(targetModel) then
            last_visibility_check[key] = { time = now, result = true }
            return true
        end

        if hit:IsA("BasePart") then
            local transparentEnough = (hit.Transparency >= settings.visibility_tolerance)
            local canCollide = hit.CanCollide
            if transparentEnough or (canCollide == false) then
                local unit = remainingDir.Unit
                currentOrigin = result.Position + unit * VISIBILITY_ADVANCE
                remainingDir = point - currentOrigin
                if remainingDir.Magnitude <= 0 then
                    last_visibility_check[key] = { time = now, result = true }
                    return true
                end
                attempts = attempts + 1
            else
                last_visibility_check[key] = { time = now, result = false }
                return false
            end
        else
            local unit = remainingDir.Unit
            currentOrigin = result.Position + unit * VISIBILITY_ADVANCE
            remainingDir = point - currentOrigin
            if remainingDir.Magnitude <= 0 then
                last_visibility_check[key] = { time = now, result = true }
                return true
            end
            attempts = attempts + 1
        end
    end

    last_visibility_check[key] = { time = now, result = false }
    return false
end

local function find_closest()
    local PlayerAmt = players:GetPlayers()
    local ClosestPlayer, ClosestViewmodel, ClosestScreenPos, ClosestPart
    local BestDistance2 = math.huge
    local screen_mid = settings.screen_middle or screen_middle
    local viewmodels_folder = workspace:FindFirstChild("Viewmodels")
    local circleRadius2 = (circle and circle.Visible) and (circle.Radius * circle.Radius) or math.huge

    hideAimIndicator()

    for _, pl in ipairs(PlayerAmt) do
        if pl == players.LocalPlayer then continue end
        local vm
        if viewmodels_folder then
            vm = viewmodels_folder:FindFirstChild(pl.Name) or viewmodels_folder:FindFirstChild("Viewmodels/" .. pl.Name)
        end
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        local vmRoot = vm.PrimaryPart or vm:FindFirstChildWhichIsA("BasePart") or vm:FindFirstChild("torso") or vm:FindFirstChild("Torso")
        if not vmRoot then continue end
        local d2 = dist2(camera.CFrame.Position, vmRoot.Position)
        if d2 > (VISIBILITY_DISTANCE_LIMIT * VISIBILITY_DISTANCE_LIMIT) then
            continue
        end

        for i = 1, #hitbox_priority_cache do
            local partName = hitbox_priority_cache[i]
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen or not point then continue end

            local vis = is_visible(aimPos, vm)
            if vis then
                showAimIndicator(point)
            end

            if settings.visibility and not vis then
                continue
            end

            local dx = point.X - screen_mid.X
            local dy = point.Y - screen_mid.Y
            local screenDist2 = dx*dx + dy*dy

            if screenDist2 > circleRadius2 then
                continue
            end

            if screenDist2 < BestDistance2 then
                BestDistance2 = screenDist2
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

    raycast_params_cache = raycast_params_cache or build_raycast_params()

    on_esp_ran(function()
        local player, closest, screen_pos, aim_part = find_closest()
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
        local aimCFrame = CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0))
        local eased = (1 - (1 - lerp) ^ 2)
        local base_cframe = camera.CFrame:Lerp(aimCFrame, eased)

        rot = rot + (user_input_service:GetMouseDelta() * 0.0005)
        camera.CFrame = base_cframe * CFrame.Angles(0, -rot.X, 0) * CFrame.Angles(-rot.Y, 0, 0)

        if lerp >= 1 then
            start = 0
            rot = Vector2.new()
            return
        end
    end)

    local old_cframe_new = clonefunction(CFrame.new)
    hook_function(CFrame.new, function(...)
        if debug.info(3, 'n') == "send_shoot"
            and settings.enabled
            and settings.silent
            and get_useable() then

            local player, closest, screen_pos, aim_part = find_closest()
            if player and closest and aim_part then
                local vis = is_visible(aim_part.Position, closest)
                if vis and screen_pos then
                    pcall(function() showAimIndicator(screen_pos) end)
                else
                    hideAimIndicator()
                end

                local stack = debug.getstack(3, 3)
                if stack and stack.Position then
                    local newCFrame = CFrame.lookAt(stack.Position, aim_part.Position)
                    debug.setstack(3, 6, newCFrame)
                end
            else
                hideAimIndicator()
            end
        end
        return old_cframe_new(...)
    end)
end

return aimbot
