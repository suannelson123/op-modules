loadstring(game:HttpGet("https://raw.githubusercontent.com/mainstreamed/amongus-hook/refs/heads/main/drawingfix.lua",true))();
if (not (game:IsLoaded() and getgenv().drawingLoaded)) then repeat task.wait() until (game:IsLoaded() and getgenv().drawingLoaded) end do
    if (getgenv().loaded) then return end;

    do -- includes

        local inculdes = {
            "sdk/memory.lua",
            "sdk/misc.lua",
            "core/aimbot.lua",
            "core/player_esp.lua",
            "core/weapon_modifications.lua",
            "core/attachment_editor.lua"
        };

        local inits = {};

        for _, file in next, (inculdes) do
            for i, v in next, (loadstring(game:HttpGet("https://github.com/suannelson123/op-modules/main/Operation%20One" .. file, true))()) do
                if (i == "init") then
                    table.insert(inits, v);
                    continue;
                end;
                rawset(getfenv(1), i, v);
            end;
        end;

        for i, v in next, (inits) do
            v();
        end;

    end;

    local camera:               Camera = cloneref(workspace.CurrentCamera);
    local screen_middle:        Vector2 = (camera.ViewportSize / 2);
    local players:              Players = get_service("Players");
    local local_player:         Player = cloneref(players.LocalPlayer);
    local replicated_storage:   ReplicatedStorage = get_service("ReplicatedStorage");
    local run_service:          RunService = get_service("RunService");
    local rbx_env:              table = getrenv();
    local viewmodels:           Folder = workspace:FindFirstChild("Viewmodels");

    do --// esp
        for i, v in next, (viewmodels:GetChildren()) do
            set_player_esp(v);
        end;

        viewmodels.ChildAdded:Connect(function(child: Instance)
            set_player_esp(child)
        end);
    end;

    do --// ui stuff
        local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
        local theme_manager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
        local save_manager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()
        local window = library:CreateWindow({Title = "KLUB | Pid: " .. game.PlaceVersion, Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2});

        local aimbot_module = rawget(getfenv(1), "aimbot") or aimbot
        local aimbot_settings = aimbot_module and aimbot_module.aimbot_settings or (rawget(getfenv(1), "aimbot_settings") or {})

        local weapon_modifications_settings = rawget(getfenv(1), "weapon_modifications_settings") or (rawget(getfenv(1), "settings") or {})
        local esp_player_settings = rawget(getfenv(1), "esp_player_settings") or {}
        local attachment_editor_settings = rawget(getfenv(1), "attachment_editor_settings") or {}

        aimbot_settings.smoothing = aimbot_settings.smoothing or 200
        aimbot_settings.circle = aimbot_settings.circle or Drawing.new("Circle")
        aimbot_settings.circle.Visible = aimbot_settings.circle.Visible or false
        aimbot_settings.circle.Radius = aimbot_settings.circle.Radius or 120

        local combat = window:AddTab("Combat") do

            local aimbot_groupbox = combat:AddLeftGroupbox("Aimbot") do

                aimbot_groupbox:AddToggle('aimbot_enable', {Text = "Enable", Default = aimbot_settings.enabled or false, Callback = function(value: boolean)
                    aimbot_settings.enabled = value;
                    if value and aimbot_module and type(aimbot_module.init) == "function" then
                        pcall(function() aimbot_module.init() end)
                    end
                end});

                aimbot_groupbox:AddToggle('aimbot_psilent', {Text = "PSilent", Default = aimbot_settings.silent or false, Callback = function(value: boolean)
                    aimbot_settings.silent = value;
                end});

                aimbot_groupbox:AddDropdown('aimbot_pressed', {Values = {"None", "shooting", "aiming", "any"} , Default = (function()
                    for i,v in ipairs({"None","shooting","aiming","any"}) do if aimbot_settings.pressed == v then return i end end
                    return 3
                end)(), Multi = false, Text = 'Key', Callback = function(Value)
                    aimbot_settings.pressed = Value;
                end});

                aimbot_groupbox:AddDropdown('aimbot_target', {Values = {"head", "torso", "closest"} , Default = (function()
                    if aimbot_settings.hitbox_priority and #aimbot_settings.hitbox_priority>0 then
                        local first = aimbot_settings.hitbox_priority[1]
                        if first == "head" then return 1 end
                        if first == "torso" then return 2 end
                    end
                    return 3
                end)(), Multi = false, Text = 'Target', Callback = function(Value)
                    if Value == "head" then
                        aimbot_settings.hitbox_priority = {"head","torso","shoulder1","shoulder2","arm1","arm2","hip1","hip2","leg1","leg2"}
                    elseif Value == "torso" then
                        aimbot_settings.hitbox_priority = {"torso","head","shoulder1","shoulder2","arm1","arm2","hip1","hip2","leg1","leg2"}
                    else
                        aimbot_settings.hitbox_priority = {"head","torso","shoulder1","shoulder2","arm1","arm2","hip1","hip2","leg1","leg2"}
                    end
                end});

                aimbot_groupbox:AddSlider('aimbot_smoothing', {Text = 'Smoothing', Default = aimbot_settings.smoothing or 200, Min = 1, Max = 1000, Rounding = 0, Compact = false, Callback = function(Value)
                    aimbot_settings.smoothing = Value;
                end});

                local aimbot_fov_enable = aimbot_groupbox:AddToggle('aimbot_fov_enable', {Text = "Fov", Default = aimbot_settings.circle.Visible or false, Callback = function(value: boolean)
                    aimbot_settings.circle.Visible = value;
                end});

                aimbot_fov_enable:AddColorPicker('aimbot_fov_color', {Default = aimbot_settings.circle.Color or Color3.fromRGB(255, 255, 255), Title = "Fov Color", Callback = function(value: Color3)
                    aimbot_settings.circle.Color = value;
                end});

                aimbot_groupbox:AddSlider('aimbot_fov_size', {Text = 'Fov Size', Default = aimbot_settings.circle.Radius or 120, Min = 1, Max = 1000, Rounding = 0, Compact = false, Callback = function(Value)
                    aimbot_settings.circle.Radius = Value;
                end});

            end;

            local weapon_modifications_groupbox = combat:AddRightGroupbox("Weapon Modifications") do

                weapon_modifications_groupbox:AddToggle('weapon_modifications_no_spread', {Text = "No Spread", Default = weapon_modifications_settings.no_spread or false, Callback = function(value: boolean)
                    weapon_modifications_settings.no_spread = value;
                end});

                weapon_modifications_groupbox:AddToggle('weapon_modifications_fast_reload', {Text = "Fast Reload", Default = weapon_modifications_settings.fast_reload or false, Callback = function(value: boolean)
                    weapon_modifications_settings.fast_reload = value;
                end});

                weapon_modifications_groupbox:AddSlider('weapon_modifications_recoil_x', {Text = 'Recoil X', Default = math.floor((weapon_modifications_settings.recoil_x or 1) * 100), Min = 0, Max = 100, Rounding = 0, Compact = false, Callback = function(Value)
                    weapon_modifications_settings.recoil_x = (Value / 100);
                end});

                weapon_modifications_groupbox:AddSlider('weapon_modifications_recoil_y', {Text = 'Recoil Y', Default = math.floor((weapon_modifications_settings.recoil_y or 1) * 100), Min = 0, Max = 100, Rounding = 0, Compact = false, Callback = function(Value)
                    weapon_modifications_settings.recoil_y = (Value / 100);
                end});

                --[[weapon_modifications_groupbox:AddSlider('weapon_modifications_firerate_multiplier', {Text = 'Firerate Multiplier', Default = 1, Min = 1, Max = 10, Rounding = 0, Compact = false, Callback = function(Value)
                    -- soon as i find a better method.
                end});]]

            end;
        --[[ soon im lazy af deal with it
            local other_groupbox = combat:AddRightGroupbox("Other") do

                other_groupbox:AddDropdown('other_hitbox_override', {Values = {"off", "head", "torso"} , Default = 1, Multi = false, Text = 'Hitbox Override', Callback = function(Value)

                end});

                other_groupbox:AddToggle('other_doubletap', {Text = "Doubletap", Default = false, Callback = function(value: boolean)

                end});

            end;
        ]]
        end;

        local esp = window:AddTab("ESP") do

            local player_esp_groupbox = esp:AddLeftGroupbox("Player") do

                local player_esp_skelton = player_esp_groupbox:AddToggle('player_esp_skelton', {Text = "Skelton", Default = esp_player_settings.skelton or false, Callback = function(value: boolean)
                    esp_player_settings.skelton = value;
                end});

                player_esp_skelton:AddColorPicker('player_esp_skelton_color', {Default = esp_player_settings.skelton_color or Color3.fromRGB(255, 255, 255), Title = "Skelton Color", Callback = function(value: Color3)
                    esp_player_settings.skelton_color = value;
                end});


                player_esp_groupbox:AddToggle('player_esp_health_bar', {Text = "Health Bar", Default = esp_player_settings.health_bar or false, Callback = function(value: boolean)
                    esp_player_settings.health_bar = value;
                end});

            end;

        end;

        local _local = window:AddTab("Local") do

            local attachment_editor_groupbox = _local:AddLeftGroupbox("Attachment Editor") do

                attachment_editor_groupbox:AddDropdown('attachment_editor_skin', {Values = {"Default", "Golden", "Diamond", "Red", "Green", "Blue", "Halloween", "Yellow", "White", "SnowCamo", "Kalash", "Skulls", "OilSpill", "HazardSkin", "ForestCamo", "ClassicStuds", "DeepRed", "FrenchSticker", "Steyr", "DesertCamo", "Ghillie", "CarbonFiber", "Space"} , Default = 1, Multi = false, Text = 'Skin', Callback = function(Value)
                    attachment_editor_settings.skin = Value;
                end});
--[[
                attachment_editor_groupbox:AddDropdown('attachment_editor_scope', {Values = {"Default", "PSO", "PMII", "ACOG", "Specter", "TA44", "Kobra", "Micro", "XPS", "DeltaPoint", "Primer"} , Default = 1, Multi = false, Text = 'Scope', Callback = function(Value)
                    attachment_editor_settings.scope = Value;
                end});

                attachment_editor_groupbox:AddDropdown('attachment_editor_barrel', {Values = {"Default", "Compensator", "FlashHider", "MuzzleBrake", "Silencer"} , Default = 1, Multi = false, Text = 'Barrel', Callback = function(Value)
                    attachment_editor_settings.barrel = Value;
                end});

                attachment_editor_groupbox:AddDropdown('attachment_editor_charm', {Values = {"Default", "AceCard", "BlueBall", "BulletCharm", "ColorfulSquares", "DiamondCharm", "LoveHeart", "LuckyCharm"} , Default = 1, Multi = false, Text = 'Charm', Callback = function(Value)
                    attachment_editor_settings.charm = Value;
                end});

                attachment_editor_groupbox:AddDropdown('attachment_editor_mag', {Values = {"Default", "DrumAA12", "DrumSkorpion", "ExtendedMP7", "ExtendedSkorpion"} , Default = 1, Multi = false, Text = 'Mag', Callback = function(Value)
                    attachment_editor_settings.mag = Value;
                end});

                attachment_editor_groupbox:AddDropdown('attachment_editor_stock', {Values = {"Default", "SwitchGlock"} , Default = 1, Multi = false, Text = 'Stock', Callback = function(Value)
                    attachment_editor_settings.stock = Value;
                end});

                attachment_editor_groupbox:AddDropdown('attachment_editor_grip', {Values = {"Default", "AngledGrip", "Bipod", "BrazilianShield", "LaserPointer", "TacticalFlashlight", "ThumbGrip", "VerticalGrip"} , Default = 1, Multi = false, Text = 'Grip', Callback = function(Value)
                    attachment_editor_settings.grip = Value;
                end});

]]
                attachment_editor_groupbox:AddButton({Text = 'Apply', DoubleClick = false, Func = function()
                    set_skin();
                    --set_scope();
                    --set_grip();
                    --set_stock();
                    --set_mag();
                    --set_charm();
                    --set_barrel();
                end});
            end;

        end;


        local ui_settings = window:AddTab("UI Settings") do
            theme_manager:SetLibrary(library);
            save_manager:SetLibrary(library);
            save_manager:IgnoreThemeSettings();
            theme_manager:SetFolder("KLUB");
            save_manager:SetFolder("KLUB/Operation One");
            save_manager:BuildConfigSection(ui_settings);
            theme_manager:ApplyToTab(ui_settings);
            save_manager:LoadAutoloadConfig();
            --replicated_storage:FindFirstChild("RemoteEvent"):FireServer('z', 5); --// anti admin
        end;
    end;

    getgenv().loaded = true;
end;
