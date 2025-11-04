local player_esp = {};
local has_esp = {};
local has_gadget_esp = {}; 
local esp_ran = {};
local gadget_esp_ran = []; 
local core_gui: CoreGui;
local players: Players;
local run_service: RunService;
local camera = cloneref(workspace.CurrentCamera);
local settings = {
    health_bar = false,
    skelton = false,
    skelton_color = Color3.fromRGB(255, 255, 255),
    
    gadget_esp = true,
    drone_esp = true,
    claymore_esp = true,
    gadget_color = Color3.fromRGB(255, 165, 0), 
};

rawset(player_esp, "set_player_esp", newcclosure(function(character: Model)
    task.wait(0.5);
    if (not (character:IsA("Model") and character:FindFirstChild("EnemyHighlight")) or has_esp[character]) then return end;
    local name: string = character.Name:gsub("Viewmodels/", "");
    local humanoid: Humanoid = players[name].Character:FindFirstChildOfClass("Humanoid");
    local torso: Part = character:FindFirstChild("torso");
    local c1, c2;
    has_esp[character] = {
        ["name"] = name,
        ["humanoid"] = humanoid,
        ["self"] = character,
        ["type"] = "player"  
    };
    local health_bar_inner = Drawing.new("Square") do
        health_bar_inner.Visible = false;
        health_bar_inner.Thickness = 0;
        health_bar_inner.Filled = true;
        health_bar_inner.ZIndex = 5;
    end;
    local health_bar_outer = Drawing.new("Square") do
        health_bar_outer.Visible = false;
        health_bar_outer.Color = Color3.new(0.152941, 0.152941, 0.152941);
        health_bar_outer.Transparency = 0.6;
        health_bar_outer.Thickness = 0;
        health_bar_outer.Filled = true;
        health_bar_outer.ZIndex = 1;
    end;
    local skeleton = Instance.new("WireframeHandleAdornment", core_gui) do
        skeleton.Color3 = Color3.new(1, 1, 1);
        skeleton.Visible = true;
        skeleton.AlwaysOnTop = true;
        skeleton.Adornee = workspace;
        skeleton.Thickness = 1;
        skeleton.ZIndex = 5;
    end;
    c1 = run_service.RenderStepped:Connect(function(delta: number)
        local point, on = to_view_point(torso.CFrame.Position);
        if (on) then
            for i, v in next, (esp_ran) do v(has_esp[character], point) end;
          
            local cf_mid, size = character:GetBoundingBox();
            local bottom_right = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new(-size.X / 2, -size.Y / 2, 0)).Position);
            local bottom_left = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new(size.X / 2, -size.Y / 2, 0)).Position);
            local head_offset = (character.head.CFrame * -Vector3.new(0, (character.head.Size.Y / 2), 0));
            if (settings.health_bar) then
                health_bar_inner.Visible = true;
                health_bar_outer.Visible = true;
                local health = math.clamp((humanoid.Health / humanoid.MaxHealth), 0, 1);
                health_bar_outer.Size = Vector2.new(bottom_left.X - bottom_right.X, 3);
                health_bar_outer.Position = Vector2.new(bottom_right.X, bottom_left.Y);
   
                health_bar_inner.Size = Vector2.new((((bottom_left.X - bottom_right.X) + 2) * health), 1);
                health_bar_inner.Position = Vector2.new(health_bar_outer.Position.X - 1, bottom_left.Y + 1);
                health_bar_inner.Color = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), health);
                health = nil;
            else
                health_bar_inner.Visible = false;
                health_bar_outer.Visible = false;
            end;
            if (settings.skelton) then
                skeleton:Clear();
                skeleton.Color3 = settings.skelton_color;
                skeleton:AddLines({character.head.Position, character.torso.Position, head_offset, character.shoulder2.Position, character.shoulder2.Position, character.arm2.Position, head_offset, character.shoulder1.Position, character.shoulder1.Position, character.arm1.Position, character.torso.Position, character.hip2.Position, character.hip2.Position, character.leg2.Position, character.torso.Position, character.hip1.Position, character.hip1.Position, character.leg1.Position});
            else
                skeleton:Clear();
            end;
          
            size, cf_mid, bottom_right, bottom_left = nil, nil, nil, nil;
        else
            skeleton:Clear();
            health_bar_inner.Visible = false;
            health_bar_outer.Visible = false;
        end;
        point = nil;
    end);
    c2 = character.AncestryChanged:Connect(function(child: Instance, parent: Instance)
        if (parent ~= nil) then return end;
        c1:Disconnect();
        has_esp[character] = nil;
        health_bar_inner:Destroy();
        health_bar_outer:Destroy();
        skeleton:Destroy();
        c2:Disconnect();
        c1, c2, health_bar_inner, health_bar_outer = nil, nil, nil, nil;
    end);
end));

rawset(player_esp, "set_gadget_esp", newcclosure(function(gadget: Model)
    if not (gadget:IsA("Model") and (gadget.Name == "Drone" or gadget.Name == "Claymore")) or has_gadget_esp[gadget] then 
        return 
    end;
    
    local gadget_name = gadget.Name;
    local primary_part = gadget.PrimaryPart or gadget:FindFirstChild("Torso") or gadget:FindFirstChild("HumanoidRootPart") or gadget:FindFirstChildOfClass("Part");
    if not primary_part then return end;
    
    has_gadget_esp[gadget] = {
        ["name"] = gadget_name,
        ["self"] = gadget,
        ["type"] = gadget_name:lower(),  
        ["primary_part"] = primary_part
    };
    
    local box = Drawing.new("Square") do
        box.Visible = false;
        box.Color = settings.gadget_color;
        box.Thickness = 2;
        box.Filled = false;
        box.Transparency = 0.5;
        box.ZIndex = 5;
    end;
    
    local name_tag = Drawing.new("Text") do
        name_tag.Visible = false;
        name_tag.Color = settings.gadget_color;
        name_tag.Size = 16;
        name_tag.Center = true;
        name_tag.Outline = true;
        name_tag.Font = 2;
        name_tag.Text = gadget_name;
        name_tag.ZIndex = 6;
    end;
    
    local connection = run_service.RenderStepped:Connect(function()
        local point, on_screen = to_view_point(primary_part.Position);
        if on_screen and settings.gadget_esp and (settings.drone_esp and gadget_name == "Drone" or settings.claymore_esp and gadget_name == "Claymore") then
            local cf_mid, size = gadget:GetBoundingBox();
            local top_left = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new(-size.X / 2, size.Y / 2, 0)).Position);
            local bottom_right = to_view_point((CFrame.new(cf_mid.Position, camera.CFrame.Position) * CFrame.new(size.X / 2, -size.Y / 2, 0)).Position);
            
            box.Size = Vector2.new(math.abs(bottom_right.X - top_left.X), math.abs(bottom_right.Y - top_left.Y));
            box.Position = Vector2.new(top_left.X, top_left.Y);
            box.Visible = true;
            
            name_tag.Position = Vector2.new(point.X, top_left.Y - 20);
            name_tag.Visible = true;
            
            for i, v in next, (gadget_esp_ran) do 
                v(has_gadget_esp[gadget], point) 
            end;
        else
            box.Visible = false;
            name_tag.Visible = false;
        end;
    end);
    
    gadget.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            connection:Disconnect();
            box:Destroy();
            name_tag:Destroy();
            has_gadget_esp[gadget] = nil;
        end
    end);
end));

rawset(player_esp, "on_esp_ran", newcclosure(function(func: (has_esp: table) -> ())
    table.insert(esp_ran, func);
    return {remove = function()
        for i, v in next, (esp_ran) do
            if (v ~= func) then continue end;
            rawset(esp_ran, i, nil);
        end;
    end};
end));

rawset(player_esp, "on_gadget_esp_ran", newcclosure(function(func: (has_gadget_esp: table) -> ())
    table.insert(gadget_esp_ran, func);
    return {remove = function()
        for i, v in next, (gadget_esp_ran) do
            if (v ~= func) then continue end;
            rawset(gadget_esp_ran, i, nil);
        end;
    end};
end));

rawset(player_esp, "get_player_from_has_esp", newcclosure(function(character: Model)
    return has_esp[character];
end));

rawset(player_esp, "get_gadget_from_has_esp", newcclosure(function(gadget: Model)
    return has_gadget_esp[gadget];
end));

rawset(player_esp, "esp_player_settings", settings);

player_esp.init = function()
    players = get_service("Players");
    run_service = get_service("RunService");
    core_gui = get_service("CoreGui");
    
    workspace.ChildAdded:Connect(function(child)
        if child.Name:match("Viewmodels/") then
            player_esp.set_player_esp(child);
        end
    end);
    
    spawn(function()
        while true do
            for _,v in pairs(workspace:GetChildren()) do
                if v:IsA("Model") and (v.Name == "Drone" or v.Name == "Claymore") and not has_gadget_esp[v] then
                    player_esp.set_gadget_esp(v);
                end
            end
            task.wait(1);
        end
    end);
end;

return player_esp;
