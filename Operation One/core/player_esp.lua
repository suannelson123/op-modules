local player_esp = {}

local has_esp = {}
local esp_ran = {}
local core_gui, players, run_service
local camera = cloneref(workspace.CurrentCamera)

local settings = {
    health_bar = false,
    skelton = false,
    skelton_color = Color3.fromRGB(255, 255, 255),

    gadget_esp = true,
    drone_esp = true,
    claymore_esp = true,
    gadget_color = Color3.fromRGB(255, 165, 0),
    gadget_transparency = 0.5,
    gadget_box_size = 16,
}

rawset(player_esp, "set_player_esp", newcclosure(function(character: Model)
    task.wait(0.5)
    if not (character:IsA("Model") and character:FindFirstChild("EnemyHighlight")) or has_esp[character] then return end

    local name = character.Name:gsub("Viewmodels/", "")
    local humanoid = players[name].Character:FindFirstChildOfClass("Humanoid")
    local torso = character:FindFirstChild("torso")
    if not (humanoid and torso) then return end

    has_esp[character] = { name = name, humanoid = humanoid, self = character }

    local health_inner = Drawing.new("Square")
    local health_outer = Drawing.new("Square")
    local skeleton = Instance.new("WireframeHandleAdornment", core_gui)

    health_inner.Thickness = 0; health_inner.Filled = true; health_inner.ZIndex = 5
    health_outer.Thickness = 0; health_outer.Filled = true; health_outer.ZIndex = 1
    health_outer.Color = Color3.fromRGB(39, 39, 39); health_outer.Transparency = 0.6

    skeleton.Color3 = Color3.new(1,1,1); skeleton.Visible = true; skeleton.AlwaysOnTop = true
    skeleton.Adornee = workspace; skeleton.Thickness = 1; skeleton.ZIndex = 5

    local c1 = run_service.RenderStepped:Connect(function()
        local point, onScreen = to_view_point(torso.Position)
        if not onScreen then
            health_inner.Visible = false; health_outer.Visible = false
            skeleton:Clear()
            return
        end

        for _, fn in ipairs(esp_ran) do fn(has_esp[character], point) end

        local cf, size = character:GetBoundingBox()
        local br = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new(-size.X/2, -size.Y/2, 0)).Position)
        local bl = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new( size.X/2, -size.Y/2, 0)).Position)
        local head_offset = character.head.CFrame * -Vector3.new(0, character.head.Size.Y/2, 0)

        if settings.health_bar then
            local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            health_outer.Size = Vector2.new(bl.X - br.X, 3)
            health_outer.Position = Vector2.new(br.X, bl.Y)
            health_inner.Size = Vector2.new(((bl.X - br.X) + 2) * health, 1)
            health_inner.Position = Vector2.new(health_outer.Position.X - 1, bl.Y + 1)
            health_inner.Color = Color3.new(1,0,0):Lerp(Color3.new(0,1,0), health)
            health_inner.Visible = true; health_outer.Visible = true
        else
            health_inner.Visible = false; health_outer.Visible = false
        end

        -- Skeleton
        if settings.skelton then
            skeleton:Clear()
            skeleton.Color3 = settings.skelton_color
            skeleton:AddLines({
                character.head.Position, character.torso.Position,
                head_offset, character.shoulder2.Position,
                character.shoulder2.Position, character.arm2.Position,
                head_offset, character.shoulder1.Position,
                character.shoulder1.Position, character.arm1.Position,
                character.torso.Position, character.hip2.Position,
                character.hip2.Position, character.leg2.Position,
                character.torso.Position, character.hip1.Position,
                character.hip1.Position, character.leg1.Position
            })
        else
            skeleton:Clear()
        end
    end)

    local c2 = character.AncestryChanged:Connect(function(_, parent)
        if parent then return end
        c1:Disconnect(); c2:Disconnect()
        has_esp[character] = nil
        health_inner:Destroy(); health_outer:Destroy(); skeleton:Destroy()
    end)
end))

-- // GADGET ESP 
local drone_esp = {}
local claymore_esp = {}

local function create_box()
    local box = Drawing.new("Square")
    box.Thickness = 2; box.Filled = false; box.Visible = false
    return box
end

local function add_gadget(model: Model, storage: table)
    if storage[model] then return end

    local box = create_box()
    local root = model:FindFirstChild("RootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    storage[model] = { box = box, c1 = nil, c2 = nil }

    local c1 = run_service.RenderStepped:Connect(function()
        local point, onScreen = to_view_point(root.Position)
        if not onScreen then
            box.Visible = false
            return
        end

        local enabled = settings.gadget_esp and (
            (model.Name == "Drone" and settings.drone_esp) or
            (model.Name == "Claymore" and settings.claymore_esp)
        )

        if not enabled then
            box.Visible = false
            return
        end

        local cf, size = model:GetBoundingBox()
        local scale = settings.gadget_box_size / 16

        local br = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new(-size.X/2 * scale, -size.Y/2 * scale, 0)).Position)
        local bl = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new( size.X/2 * scale, -size.Y/2 * scale, 0)).Position)
        local tr = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new(-size.X/2 * scale,  size.Y/2 * scale, 0)).Position)
        local tl = to_view_point((CFrame.new(cf.Position, camera.CFrame.Position) * CFrame.new( size.X/2 * scale,  size.Y/2 * scale, 0)).Position)

        box.Size = Vector2.new(bl.X - br.X, tl.Y - bl.Y)
        box.Position = Vector2.new(br.X, bl.Y)
        box.Color = settings.gadget_color
        box.Transparency = settings.gadget_transparency
        box.Visible = true
    end)

    local c2 = model.AncestryChanged:Connect(function(_, parent)
        if parent then return end
        c1:Disconnect(); c2:Disconnect()
        box:Destroy()
        storage[model] = nil
    end)

    storage[model].c1 = c1
    storage[model].c2 = c2
end

task.spawn(function()
    while task.wait(1) do
        local _, drones, claymores = (function()
            local team = players.LocalPlayer and players.LocalPlayer.Team
            local enemies = {}
            local drones = {}
            local claymores = {}

            for _, plr in players:GetPlayers() do
                if plr.Character and plr.Team ~= team then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        table.insert(enemies, plr.Character)
                    end
                end
            end

            for _, v in workspace:GetChildren() do
                if v:IsA("Model") then
                    if v.Name == "Drone" then table.insert(drones, v)
                    elseif v.Name == "Claymore" then table.insert(claymores, v)
                    end
                end
            end

            return enemies, drones, claymores
        end)()

        for _, v in drones do add_gadget(v, drone_esp) end
        for _, v in claymores do add_gadget(v, claymore_esp) end
    end
end)

rawset(player_esp, "on_esp_ran", newcclosure(function(func)
    table.insert(esp_ran, func)
    return { remove = function()
        for i, v in ipairs(esp_ran) do
            if v == func then rawset(esp_ran, i, nil) end
        end
    end }
end))

rawset(player_esp, "get_player_from_has_esp", newcclosure(function(char)
    return has_esp[char]
end))

rawset(player_esp, "esp_player_settings", settings)

player_esp.init = function()
    players = get_service("Players")
    run_service = get_service("RunService")
    core_gui = get_service("CoreGui")
end

return player_esp
