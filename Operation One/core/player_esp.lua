local player_esp = {};

local has_esp      = {};   
local esp_ran      = {}; 
local core_gui     : CoreGui;
local players      : Players;
local run_service  : RunService;
local workspace    = cloneref(workspace);
local camera       = cloneref(workspace.CurrentCamera);

local settings = {
    health_bar      = false,
    skeleton        = false,
    skeleton_color  = Color3.fromRGB(255, 255, 255),
    claymore_box    = true,
    claymore_color  = Color3.fromRGB(255, 0, 0),
    drone_box       = true,
    drone_color     = Color3.fromRGB(0, 255, 255),
    box_scale       = 1,        -- default 1x
    gadget_color    = Color3.fromRGB(255, 165, 0)
};

local function to_view_point(worldPos: Vector3): (Vector2, boolean)
    local screen, onScreen = camera:WorldToViewportPoint(worldPos);
    return Vector2.new(screen.X, screen.Y), onScreen;
end

rawset(player_esp, "set_player_esp", newcclosure(function(character: Model)
    task.wait(0.5);
    if (not (character:IsA("Model") and character:FindFirstChild("EnemyHighlight")) or has_esp[character]) then return end;

    local name     : string   = character.Name:gsub("Viewmodels/", "");
    local humanoid : Humanoid = players[name].Character:FindFirstChildOfClass("Humanoid");
    local torso    : Part     = character:FindFirstChild("torso");

    local c1, c2;

    has_esp[character] = {
        ["name"]     = name,
        ["humanoid"] = humanoid,
        ["self"]     = character
    };

    local health_bar_inner = Drawing.new("Square") do
        health_bar_inner.Visible      = false;
        health_bar_inner.Thickness    = 0;
        health_bar_inner.Filled       = true;
        health_bar_inner.ZIndex       = 5;
    end;
    local health_bar_outer = Drawing.new("Square") do
        health_bar_outer.Visible     = false;
        health_bar_outer.Color        = Color3.new(0.152941, 0.152941, 0.152941);
        health_bar_outer.Transparency = 0.6;
        health_bar_outer.Thickness    = 0;
        health_bar_outer.Filled       = true;
        health_bar_outer.ZIndex       = 1;
    end;

    local skeleton = Instance.new("WireframeHandleAdornment", core_gui) do
        skeleton.Color3      = Color3.new(1,1,1);
        skeleton.Visible     = true;
        skeleton.AlwaysOnTop = true;
        skeleton.Adornee     = workspace;
        skeleton.Thickness   = 1;
        skeleton.ZIndex      = 5;
    end;

    c1 = run_service.RenderStepped:Connect(function()
        local point, on = to_view_point(torso.CFrame.Position);
        if (on) then
            for _, v in ipairs(esp_ran) do v(has_esp[character], point) end;

            local cf_mid, size = character:GetBoundingBox();
            local bottom_right = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new(-size.X/2, -size.Y/2, 0)).Position);
            local bottom_left  = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new( size.X/2, -size.Y/2, 0)).Position);
            local head_offset  = character.head.CFrame * -Vector3.new(0, character.head.Size.Y/2, 0);

            if settings.health_bar then
                health_bar_inner.Visible = true;
                health_bar_outer.Visible = true;

                local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1);

                health_bar_outer.Size     = Vector2.new(bottom_left.X - bottom_right.X, 3);
                health_bar_outer.Position = Vector2.new(bottom_right.X, bottom_left.Y);

                health_bar_inner.Size     = Vector2.new(((bottom_left.X - bottom_right.X) + 2) * health, 1);
                health_bar_inner.Position = Vector2.new(health_bar_outer.Position.X - 1, bottom_left.Y + 1);
                health_bar_inner.Color    = Color3.new(1,0,0):Lerp(Color3.new(0,1,0), health);
            else
                health_bar_inner.Visible = false;
                health_bar_outer.Visible = false;
            end

            if settings.skeleton then
                skeleton:Clear();
                skeleton.Color3 = settings.skeleton_color;
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
                });
            else
                skeleton:Clear();
            end
        else
            skeleton:Clear();
            health_bar_inner.Visible = false;
            health_bar_outer.Visible = false;
        end
    end);

    c2 = character.AncestryChanged:Connect(function(_, parent)
        if parent then return end
        c1:Disconnect();
        has_esp[character] = nil;
        health_bar_inner:Destroy();
        health_bar_outer:Destroy();
        skeleton:Destroy();
        c2:Disconnect();
    end);
end));

rawset(player_esp, "on_esp_ran", newcclosure(function(func)
    table.insert(esp_ran, func);
    return { remove = function()
        for i, v in ipairs(esp_ran) do
            if v == func then table.remove(esp_ran, i); break end
        end
    end};
end));

rawset(player_esp, "get_player_from_has_esp", newcclosure(function(character: Model)
    return has_esp[character];
end));

rawset(player_esp, "esp_player_settings", settings);

local claymore_drawings = {};
local drone_drawings    = {};

local function create_box_drawing(color: Color3)
    local box = Drawing.new("Square");
    box.Thickness    = 2;
    box.Filled       = false;
    box.Color        = color;
    box.Transparency = 1;
    box.Visible      = false;
    return box;
end

local function update_claymore_drone()
    for _, claymore in ipairs(workspace:GetChildren()) do
        if claymore.Name == "Claymore" and claymore:IsA("Model") then
            local root = claymore:FindFirstChild("RootPart") or claymore.PrimaryPart;
            if root then
                local drawing = claymore_drawings[claymore] or create_box_drawing(settings.claymore_color);
                claymore_drawings[claymore] = drawing;

                local pos, onScreen = to_view_point(root.Position);
                if onScreen and settings.claymore_box then
                    local size = root.Size;
                    local half = size/2;
                    local tl = to_view_point((root.CFrame * CFrame.new(-half.X,  half.Y, 0)).Position);
                    local br = to_view_point((root.CFrame * CFrame.new( half.X, -half.Y, 0)).Position);
                    local w  = math.abs(br.X - tl.X);
                    local h  = math.abs(br.Y - tl.Y);

                    drawing.Visible   = true;
                    drawing.Size      = Vector2.new(w, h);
                    drawing.Position  = Vector2.new(tl.X, tl.Y);
                else
                    drawing.Visible = false;
                end
            end
        end
    end

    for _, drone in ipairs(workspace:GetChildren()) do
        if drone.Name == "Drone" and drone:IsA("Model") then
            local root = drone:FindFirstChild("RootPart") or drone.PrimaryPart;
            if root then
                local drawing = drone_drawings[drone] or create_box_drawing(settings.drone_color);
                drone_drawings[drone] = drawing;

                local pos, onScreen = to_view_point(root.Position);
                if onScreen and settings.drone_box then
                    local size = root.Size;
                    local half = size/2;
                    local tl = to_view_point((root.CFrame * CFrame.new(-half.X,  half.Y, 0)).Position);
                    local br = to_view_point((root.CFrame * CFrame.new( half.X, -half.Y, 0)).Position);
                    local w  = math.abs(br.X - tl.X);
                    local h  = math.abs(br.Y - tl.Y);

                    drawing.Visible   = true;
                    drawing.Size      = Vector2.new(w, h);
                    drawing.Position  = Vector2.new(tl.X, tl.Y);
                else
                    drawing.Visible = false;
                end
            end
        end
    end
end

run_service.RenderStepped:Connect(update_claymore_drone);

workspace.ChildRemoved:Connect(function(child)
    if claymore_drawings[child] then
        claymore_drawings[child]:Remove();
        claymore_drawings[child] = nil;
    end
    if drone_drawings[child] then
        drone_drawings[child]:Remove();
        drone_drawings[child] = nil;
    end
end);

player_esp.init = function()
    players     = get_service("Players");
    run_service = get_service("RunService");
    core_gui    = get_service("CoreGui");
end;

return player_esp;
