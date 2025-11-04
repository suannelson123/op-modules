loadstring(game:HttpGet("https://raw.githubusercontent.com/mainstreamed/amongus-hook/refs/heads/main/drawingfix.lua", true))();

if not (game:IsLoaded() and getgenv().drawingLoaded) then
    repeat task.wait() until (game:IsLoaded() and getgenv().drawingLoaded)
end

do
    if getgenv().loaded then return end

    local base_url = "https://raw.githubusercontent.com/suannelson123/op-modules/main/Operation%20One/" 
    local includes = {
        "sdk/memory.lua",
        "sdk/misc.lua",
        "core/aimbot.lua",
        "core/player_esp.lua",
        "core/weapon_modifications.lua",
        "core/attachment_editor.lua"
    }

    local inits = {}

    for _, file in next, includes do
        local url = base_url .. file
        print("[Includes] Fetching:", url)

        local ok, response = pcall(function()
            return game:HttpGet(url, true)
        end)

        if not ok or not response or response == "" then
            warn("[Includes] Failed to fetch:", file, "-", response or "nil / empty response")
            continue
        end

        local first8 = tostring(response):sub(1, 8)
        if first8:match("^%s*<") or response:find("404") or response:find("Not Found") then
            warn("[Includes] Bad response (probably HTML). Check URL or repo visibility:", url)
            warn("[Includes] response snippet:", tostring(response):sub(1, 200))
            continue
        end

        local chunk, loadErr = loadstring(response)
        if not chunk then
            warn("[Includes] Failed to compile:", file, "-", loadErr)
            continue
        end

        local success, result = pcall(chunk)
        if not success then
            warn("[Includes] Runtime error when executing:", file, "-", result)
            continue
        end

        if type(result) ~= "table" then
            warn("[Includes] Module did not return a table:", file)
            continue
        end

        for i, v in next, result do
            if i == "init" and type(v) == "function" then
                table.insert(inits, v)
            else
                rawset(getfenv(1), i, v)
            end
        end
    end

    for _, init in next, inits do
        local ok2, err2 = pcall(init)
        if not ok2 then
            warn("[Includes] init() error:", err2)
        end
    end
end

local camera               = cloneref(workspace.CurrentCamera)
local screen_middle        = camera.ViewportSize / 2
local players              = get_service("Players")
local local_player         = cloneref(players.LocalPlayer)
local replicated_storage   = get_service("ReplicatedStorage")
local run_service          = get_service("RunService")
local viewmodels           = workspace:FindFirstChild("Viewmodels")

do
    for _, v in next, viewmodels:GetChildren() do
        set_player_esp(v)
    end

    viewmodels.ChildAdded:Connect(set_player_esp)
end

do
    local library       = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
    local theme_manager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
    local save_manager  = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()

    local window = library:CreateWindow({
        Title = "BOrat na tite2 | Pid: " .. game.PlaceVersion,
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    })

    local combat = window:AddTab("Combat") do

        local aimbot_groupbox = combat:AddLeftGroupbox("Aimbot") do
            aimbot_groupbox:AddToggle('aimbot_enable', {
                Text = "Enable",
                Default = false,
                Callback = function(value) aimbot_settings.enabled = value end
            })

            aimbot_groupbox:AddToggle('aimbot_psilent', {
                Text = "PSilent",
                Default = false,
                Callback = function(value) aimbot_settings.silent = value end
            })

            aimbot_groupbox:AddDropdown('aimbot_pressed', {
                Values = {"None", "shooting", "aiming", "any"},
                Default = 3,
                Multi = false,
                Text = 'Key',
                Callback = function(Value) aimbot_settings.pressed = Value end
            })

            aimbot_groupbox:AddSlider('aimbot_smoothing', {
                Text = 'Smoothing',
                Default = 1,
                Min = 1,
                Max = 1000,
                Rounding = 0,
                Callback = function(Value) aimbot_settings.smoothing = Value end
            })

            local fov_toggle = aimbot_groupbox:AddToggle('aimbot_fov_enable', {
                Text = "FOV Circle",
                Default = false,
                Callback = function(value) aimbot_settings.circle.Visible = value end
            })

            fov_toggle:AddColorPicker('aimbot_fov_color', {
                Default = Color3.fromRGB(255, 255, 255),
                Title = "FOV Color",
                Callback = function(value) aimbot_settings.circle.Color = value end
            })

            aimbot_groupbox:AddSlider('aimbot_fov_size', {
                Text = 'FOV Size',
                Default = 120,
                Min = 10,
                Max = 1000,
                Rounding = 0,
                Callback = function(Value) aimbot_settings.circle.Radius = Value end
            })
        end

        local weapon_mods = combat:AddRightGroupbox("Weapon Modifications") do
            weapon_mods:AddToggle('weapon_modifications_no_spread', {
                Text = "No Spread",
                Default = false,
                Callback = function(value) weapon_modifications_settings.no_spread = value end
            })

            weapon_mods:AddToggle('weapon_modifications_fast_reload', {
                Text = "Fast Reload",
                Default = false,
                Callback = function(value) weapon_modifications_settings.fast_reload = value end
            })

            weapon_mods:AddSlider('weapon_modifications_recoil_x', {
                Text = 'Recoil X',
                Default = 100,
                Min = 0,
                Max = 100,
                Rounding = 0,
                Callback = function(Value) weapon_modifications_settings.recoil_x = Value / 100 end
            })

            weapon_mods:AddSlider('weapon_modifications_recoil_y', {
                Text = 'Recoil Y',
                Default = 100,
                Min = 0,
                Max = 100,
                Rounding = 0,
                Callback = function(Value) weapon_modifications_settings.recoil_y = Value / 100 end
            })
        end
    end

    local esp = window:AddTab("ESP") do

        local player_group = esp:AddLeftGroupbox("Player") do

            local skeleton_toggle = player_group:AddToggle('player_esp_skeleton', {
                Text = "Skeleton",
                Default = false,
                Callback = function(value)
                    player_esp.esp_player_settings.skeleton = value
                end
            })

            skeleton_toggle:AddColorPicker('player_esp_skeleton_color', {
                Default = Color3.fromRGB(255, 255, 255),
                Title = "Skeleton Color",
                Callback = function(color)
                    player_esp.esp_player_settings.skeleton_color = color
                end
            })

            player_group:AddToggle('player_esp_health_bar', {
                Text = "Health Bar",
                Default = false,
                Callback = function(value)
                    player_esp.esp_player_settings.health_bar = value
                end
            })
        end

        local gadget_group = esp:AddRightGroupbox("Claymores & Drones") do

            local claymore_toggle = gadget_group:AddToggle('esp_claymore_box', {
                Text = "Claymore Boxes",
                Default = true,
                Callback = function(value)
                    player_esp.esp_player_settings.claymore_box = value
                end
            })

            claymore_toggle:AddColorPicker('esp_claymore_color', {
                Default = Color3.fromRGB(255, 0, 0),
                Title = "Claymore Color",
                Callback = function(color)
                    player_esp.esp_player_settings.claymore_color = color
                end
            })

            local drone_toggle = gadget_group:AddToggle('esp_drone_box', {
                Text = "Drone Boxes",
                Default = true,
                Callback = function(value)
                    player_esp.esp_player_settings.drone_box = value
                end
            })

            drone_toggle:AddColorPicker('esp_drone_color', {
                Default = Color3.fromRGB(0, 255, 255),
                Title = "Drone Color",
                Callback = function(color)
                    player_esp.esp_player_settings.drone_color = color
                end
            })
        end
    end

    local _local = window:AddTab("Local") do
        local attachment_editor = _local:AddLeftGroupbox("Attachment Editor") do

            attachment_editor:AddDropdown('attachment_editor_skin', {
                Values = {"Default", "Golden", "Diamond", "Red", "Green", "Blue", "Halloween", "Yellow", "White", "SnowCamo", "Kalash", "Skulls", "OilSpill", "HazardSkin", "ForestCamo", "ClassicStuds", "DeepRed", "FrenchSticker", "Steyr", "DesertCamo", "Ghillie", "CarbonFiber", "Space"},
                Default = 1,
                Multi = false,
                Text = 'Skin',
                Callback = function(Value)
                    attachment_editor_settings.skin = Value
                end
            })

            attachment_editor:AddButton({
                Text = 'Apply',
                DoubleClick = false,
                Func = function()
                    set_skin()
                end
            })
        end
    end

    local ui_settings = window:AddTab("UI Settings") do
        theme_manager:SetLibrary(library)
        save_manager:SetLibrary(library)
        save_manager:IgnoreThemeSettings()
        theme_manager:SetFolder("KLUB")
        save_manager:SetFolder("KLUB/Operation One")
        save_manager:BuildConfigSection(ui_settings)
        theme_manager:ApplyToTab(ui_settings)
        save_manager:LoadAutoloadConfig()
    end
end

getgenv().loaded = true
end
