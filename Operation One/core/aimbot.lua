local aimbot = {}

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local camera           = cloneref(Workspace.CurrentCamera)

local settings = {
    enabled            = false,
    silent             = false,
    smoothing          = 200,      
    pressed            = "aiming",
    visibility         = false,
    visibility_tolerance = 0,
    circle             = nil,      
    hitbox_priority    = { "head", "torso", "shoulder1", "shoulder2", "hip1", "hip2", "leg1", "leg2" },
    hitbox_offset      = Vector3.new(0, 0, 0)
}
rawset(aimbot, "aimbot_settings", settings)

local circle = Drawing.new("Circle")
circle.Visible   = false
circle.Radius    = 120
circle.Filled    = false
circle.Thickness = 1
circle.Color     = Color3.new(1,1,1)

local indicator = Drawing.new("Circle")
indicator.Visible = false
indicator.Radius  = 5
indicator.Filled  = true
indicator.Thickness = 1
indicator.NumSides = 16
indicator.Transparency = 1
indicator.Color   = Color3.fromRGB(0,255,0)

local viewmodelsFolder = Workspace:WaitForChild("Viewmodels", 5)
local cachedPlayers    = {}
local targetCache      = nil   
local aimStart         = 0
local rot              = Vector2.new()
local screenCenter     = camera.ViewportSize / 2

RunService.Heartbeat:Connect(function()
    screenCenter = camera.ViewportSize / 2
    circle.Position = screenCenter
end)

task.spawn(function()
    while task.wait(0.5) do
        cachedPlayers = Players:GetPlayers()
    end
end)

local function get_useable()
    if settings.pressed == "None"     then return true end
    if settings.pressed == "shooting" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if settings.pressed == "aiming"   then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if settings.pressed == "any"      then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    return false
end

local function is_visible(point, targetModel)
    if not settings.visibility then return true end
    local origin = camera.CFrame.Position
    local dir    = point - origin
    if dir.Magnitude < 1 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {Players.LocalPlayer.Character}

    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    local hit = result.Instance
    return hit and (hit == targetModel or hit:IsDescendantOf(targetModel))
end

local FIND_RATE = 0.033  
local lastFind  = 0

local function find_closest()
    local now = tick()
    if now - lastFind < FIND_RATE then return targetCache end
    lastFind = now

    local bestDist = math.huge
    local best = nil

    for _, pl in ipairs(cachedPlayers) do
        if pl == Players.LocalPlayer then continue end
        local vm = viewmodelsFolder and viewmodelsFolder:FindFirstChild(pl.Name)
        if not vm or not vm:FindFirstChild("EnemyHighlight") then continue end

        for _, partName in ipairs(settings.hitbox_priority) do
            local part = vm:FindFirstChild(partName)
            if not part then continue end

            local worldPos = part.Position + settings.hitbox_offset
            local scr, onScreen = camera:WorldToViewportPoint(worldPos)
            if not onScreen then continue end

            local screenPos = Vector2.new(scr.X, scr.Y)
            local dist2D = (screenPos - screenCenter).Magnitude

            if circle.Visible and dist2D > circle.Radius then continue end
            if settings.visibility and not is_visible(worldPos, vm) then continue end

            if dist2D < bestDist then
                bestDist = dist2D
                best = {
                    player    = pl,
                    vm        = vm,
                    screenPos = screenPos,
                    part      = part,
                    worldPos  = worldPos
                }
                break   
            end
        end
    end

    if best then
        indicator.Position = best.screenPos
        indicator.Visible  = true
    else
        indicator.Visible = false
    end

    targetCache = best
    return best
end

RunService.RenderStepped:Connect(function(dt)
    if not settings.enabled or not get_useable() or settings.silent then
        aimStart = 0
        rot = Vector2.new()
        return
    end

    local target = find_closest()
    if not target or not target.part then return end

    aimStart = aimStart + (dt * 1000)
    local t = math.clamp(aimStart / settings.smoothing, 0, 1)
    local eased = 1 - (1 - t) ^ 2

    local lookCFrame = CFrame.lookAt(camera.CFrame.Position, target.part.Position, Vector3.new(0,1,0))
    camera.CFrame = camera.CFrame:Lerp(lookCFrame, eased)

    if t >= 1 then aimStart = 0 end
end)

local oldCFrameNew = clonefunction(CFrame.new)

hookfunction(CFrame.new, function(pos, lookAt, up)
    if not (settings.enabled and settings.silent and get_useable()) then
        return oldCFrameNew(pos, lookAt, up)
    end

    local target = targetCache
    if target and target.part then
        if is_visible(target.part.Position, target.vm) then
            return CFrame.lookAt(pos, target.part.Position, up or Vector3.new(0,1,0))
        end
    end
    return oldCFrameNew(pos, lookAt, up)
end)

aimbot.init = function() end  
return aimbot
