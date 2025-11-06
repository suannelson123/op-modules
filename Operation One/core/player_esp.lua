local player_esp = {}

local has_esp = {}
local esp_ran = {}
local object_esp = {}
local core_gui
local players
local run_service
local camera = cloneref(workspace.CurrentCamera)

local settings = {
    health_bar = false,
    skelton = false,
    skelton_color = Color3.fromRGB(255, 255, 255),
    show_claymores = false,
    show_drones = false,
    claymore_color = Color3.fromRGB(255, 0, 0),
    drone_color = Color3.fromRGB(0, 255, 255),
}

rawset(player_esp, "set_player_esp", newcclosure(function(character: Model)
    task.wait(0.5)
    if not (character:IsA("Model") and character:FindFirstChild("EnemyHighlight")) or has_esp[character] then return end

    local name = character.Name:gsub("Viewmodels/", "")
    local humanoid = players[name] and players[name].Character and players[name].Character:FindFirstChildOfClass("Humanoid")
    local torso = character:FindFirstChild("torso")

    if not humanoid or not torso then return end

    local c1, c2
    has_esp[character] = {
        name = name,
        humanoid = humanoid,
        self = character
    }

    local health_bar_inner = Drawing.new("Square")
    health_bar_inner.Visible = false
    health_bar_inner.Thickness = 0
    health_bar_inner.Filled = true
    health_bar_inner.ZIndex = 5

    local health_bar_outer = Drawing.new("Square")
    health_bar_outer.Visible = false
    health_bar_outer.Color = Color3.new(0.152941, 0.152941, 0.152941)
    health_bar_outer.Transparency = 0.6
    health_bar_outer.Thickness = 0
    health_bar_outer.Filled = true
    health_bar_outer.ZIndex = 1

    local skeleton = Instance.new("WireframeHandleAdornment", core_gui)
    skeleton.Color3 = Color3.new(1, 1, 1)
    skeleton.Visible = true
    skeleton.AlwaysOnTop = true
    skeleton.Adornee = workspace
    skeleton.Thickness = 1
    skeleton.ZIndex = 5

    c1 = run_service.RenderStepped:Connect(function()
        local point, on = camera:WorldToViewportPoint(torso.Position)
        if on then
            for _, v in next, esp_ran do
                v(has_esp[character], point)
            end

            local cf_mid, size = character:GetBoundingBox()
            local bottom_right = camera:WorldToViewportPoint((cf_mid.Position + Vector3.new(-size.X/2, -size.Y/2, 0)))
            local bottom_left = camera:WorldToViewportPoint((cf_mid.Position + Vector3.new(size.X/2, -size.Y/2, 0)))
            local head_offset = (character.head.CFrame * -Vector3.new(0, (character.head.Size.Y / 2), 0))

            if settings.health_bar then
                health_bar_inner.Visible = true
                health_bar_outer.Visible = true

                local health = math.clamp((humanoid.Health / humanoid.MaxHealth), 0, 1)
                health_bar_outer.Size = Vector2.new(bottom_left.X - bottom_right.X, 3)
                health_bar_outer.Position = Vector2.new(bottom_right.X, bottom_left.Y)
                health_bar_inner.Size = Vector2.new(((bottom_left.X - bottom_right.X) + 2) * health, 1)
                health_bar_inner.Position = Vector2.new(health_bar_outer.Position.X - 1, bottom_left.Y + 1)
                health_bar_inner.Color = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), health)
            else
                health_bar_inner.Visible = false
                health_bar_outer.Visible = false
            end

            if settings.skelton then
                skeleton:Clear()
                skeleton.Color3 = settings.skelton_color
                skeleton:AddLines({
                    character.head.Position, character.torso.Position, head_offset,
                    character.shoulder2.Position, character.shoulder2.Position, character.arm2.Position,
                    head_offset, character.shoulder1.Position, character.shoulder1.Position, character.arm1.Position,
                    character.torso.Position, character.hip2.Position, character.hip2.Position, character.leg2.Position,
                    character.torso.Position, character.hip1.Position, character.hip1.Position, character.leg1.Position
                })
            else
                skeleton:Clear()
            end
        else
            skeleton:Clear()
            health_bar_inner.Visible = false
            health_bar_outer.Visible = false
        end
    end)

    c2 = character.AncestryChanged:Connect(function(_, parent)
        if parent ~= nil then return end
        c1:Disconnect()
        has_esp[character] = nil
        health_bar_inner:Remove()
        health_bar_outer:Remove()
        skeleton:Destroy()
        c2:Disconnect()
    end)
end))

local function add_object_esp(obj: Instance, color: Color3)
    if object_esp[obj] then return end

    local box_outline = Drawing.new("Square")
    box_outline.Thickness = 3
    box_outline.Color = Color3.new(0, 0, 0)
    box_outline.Filled = false
    box_outline.Visible = false
    box_outline.ZIndex = 4

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = color
    box.Filled = false
    box.Visible = false
    box.ZIndex = 5

    local conn
    conn = run_service.RenderStepped:Connect(function()
        if not obj or not obj:IsDescendantOf(workspace) then
            box:Remove()
            box_outline:Remove()
            object_esp[obj] = nil
            conn:Disconnect()
            return
        end

        local cf, size = obj:GetBoundingBox()
        local corners = {
            cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
            cf * Vector3.new(size.X/2, size.Y/2, size.Z/2)
        }

        local screenPos1, onScreen1 = camera:WorldToViewportPoint(corners[1])
        local screenPos2, onScreen2 = camera:WorldToViewportPoint(corners[2])
        if not (onScreen1 or onScreen2) then
            box.Visible = false
            box_outline.Visible = false
            return
        end

        if obj.Name == "Claymore" then
            box.Color = settings.claymore_color
        elseif obj.Name == "Drone" then
            box.Color = settings.drone_color
        end

        local minX = math.min(screenPos1.X, screenPos2.X)
        local minY = math.min(screenPos1.Y, screenPos2.Y)
        local width = math.abs(screenPos2.X - screenPos1.X)
        local height = math.abs(screenPos2.Y - screenPos1.Y)

        box.Position = Vector2.new(minX, minY)
        box.Size = Vector2.new(width, height)
        box.Visible = true

        box_outline.Position = box.Position
        box_outline.Size = box.Size
        box_outline.Visible = true
    end)

    object_esp[obj] = {
        box = box,
        outline = box_outline,
        conn = conn
    }
end

local function track_objects()
    for _, obj in ipairs(workspace:GetChildren()) do
        if settings.show_claymores and obj.Name == "Claymore" then
            add_object_esp(obj, settings.claymore_color)
        elseif settings.show_drones and obj.Name == "Drone" then
            add_object_esp(obj, settings.drone_color)
        end
    end

    workspace.ChildAdded:Connect(function(obj)
        if settings.show_claymores and obj.Name == "Claymore" then
            add_object_esp(obj, settings.claymore_color)
        elseif settings.show_drones and obj.Name == "Drone" then
            add_object_esp(obj, settings.drone_color)
        end
    end)
end

rawset(player_esp, "on_esp_ran", newcclosure(function(func)
    table.insert(esp_ran, func)
    return {
        remove = function()
            for i, v in next, esp_ran do
                if v == func then
                    esp_ran[i] = nil
                    break
                end
            end
        end
    }
end))

rawset(player_esp, "get_player_from_has_esp", newcclosure(function(character)
    return has_esp[character]
end))

rawset(player_esp, "esp_player_settings", settings)

player_esp.init = function()
    players = get_service("Players")
    run_service = get_service("RunService")
    core_gui = get_service("CoreGui")
    track_objects()
end

return player_esp
