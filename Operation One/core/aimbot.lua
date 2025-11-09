local aimbot = {}
local user_input_service
local run_service
local players
local camera = workspace.CurrentCamera and cloneref(workspace.CurrentCamera) or nil
local start = 0
local rot = Vector2.new()

local circle = nil
if typeof(Drawing) == "table" and type(Drawing.new) == "function" then
    circle = Drawing.new("Circle")
end

local settings = {
    enabled = false,
    silent = false,
    circle = circle,
    screen_middle = (camera and camera.ViewportSize) and (camera.ViewportSize / 2) or Vector2.new(0, 0),
    smoothing = 200,
    pressed = "aiming",

    visibility = false,
    visibility_tolerance = 0.8,

    hitbox_priority = {
        "head", "torso", "shoulder1", "shoulder2",
        "arm1", "arm2", "hip1", "hip2", "leg1", "leg2"
    },
    hitbox_offset = Vector3.new(0, 0, 0)
}

local screen_middle = settings.screen_middle
local viewmodels_folder = workspace:FindFirstChild("Viewmodels")

if settings.circle then
    settings.circle.Visible = false
    settings.circle.Radius = 120
    settings.circle.Filled = false
    settings.circle.Thickness = 1
    settings.circle.Color = Color3.new(1, 1, 1)
    settings.circle.Position = screen_middle
end

local aim_indicator = nil
if typeof(Drawing) == "table" and type(Drawing.new) == "function" then
    aim_indicator = Drawing.new("Circle")
    aim_indicator.Visible = false
    aim_indicator.Radius = 5
    aim_indicator.Filled = true
    aim_indicator.Thickness = 1
    aim_indicator.NumSides = 16
    aim_indicator.Transparency = 1
    aim_indicator.Color = Color3.fromRGB(0, 255, 0)
end

local function hideAimIndicator()
    if aim_indicator then aim_indicator.Visible = false end
end

local function showAimIndicator(posVec2)
    if aim_indicator then
        aim_indicator.Position = posVec2
        aim_indicator.Visible = true
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

local function is_visible(point, targetModel)
    if not camera or not camera.CFrame then return false end

    local origin = camera.CFrame.Position
    local direction = (point - origin)
    if direction.Magnitude <= 0 then return true end

    local params = RaycastParams.new()
    local filters = {}
    local local_char = players.LocalPlayer and players.LocalPlayer.Character
    if local_char then table.insert(filters, local_char) end

    local local_vm = viewmodels_folder and viewmodels_folder:FindFirstChild("Viewmodels/" .. players.LocalPlayer.Name)
    if local_vm then table.insert(filters, local_vm) end

    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = filters

    local result = workspace:Raycast(origin, direction, params)
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

local function find_closest()
    if not players then return nil end
    local all_players = players:GetPlayers()
    local closest_player, closest_vm, closest_screen_pos, closest_part
    local best_distance = math.huge
    local screen_mid = screen_middle
    local vm_folder = viewmodels_folder

    for _, pl in ipairs(all_players) do
        if pl == players.LocalPlayer then continue end

        local vm = vm_folder and vm_folder:FindFirstChild(pl.Name)
        if not vm then continue end

        local enemy_highlight = vm:FindFirstChild("EnemyHighlight")
        if not enemy_highlight or not enemy_highlight.Enabled then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local aimPos = part.Position + settings.hitbox_offset
            local point, onScreen = to_view_point(aimPos)
            if not onScreen then continue end

            local screenDist = (point - screen_mid).Magnitude
            if settings.circle and settings.circle.Visible and screenDist > settings.circle.Radius then
                continue
            end

            if screenDist < best_distance then
                best_distance = screenDist
                closest_player = pl
                closest_vm = vm
                closest_screen_pos = point
                closest_part = part
            end
        end
    end

    return closest_player, closest_vm, closest_screen_pos, closest_part
end

rawset(aimbot, "aimbot_settings", settings)

aimbot.init = function()
    user_input_service = get_service("UserInputService")
    run_service = get_service("RunService")
    players = get_service("Players")

    camera = workspace.CurrentCamera or camera
    local last_viewport = camera and camera.ViewportSize or Vector2.new(0,0)

    if run_service then
        run_service.RenderStepped:Connect(function()
            if not camera then return end
            local new_size = camera.ViewportSize
            if new_size ~= last_viewport then
                screen_middle = new_size / 2
                if settings.circle then
                    settings.circle.Position = screen_middle
                end
                last_viewport = new_size
            end
        end)
    end

    on_esp_ran(function()
        local player, closest, screen_pos, aim_part = find_closest()
        if not (player and closest and aim_part) then
            hideAimIndicator()
            return
        end

        local isVisible = not settings.visibility or is_visible(aim_part.Position, closest)
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
            CFrame.lookAt(camera.CFrame.Position, aim_part.Position, Vector3.new(0, 1, 0)),
            (1 - (1 - lerp) ^ 2)
        )
        rot += (user_input_service:GetMouseDelta() * 0.0005)
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

            local player, closest, screen_pos, aim_part = find_closest()
            if player and closest and aim_part then
                local isVisible = not settings.visibility or is_visible(aim_part.Position, closest)
                if isVisible and screen_pos then
                    showAimIndicator(screen_pos)
                    debug.setstack(3, 6, CFrame.lookAt(debug.getstack(3, 3).Position, aim_part.Position))
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
