--Workspace.Model.{Cabin Derelict Oilrig Mall }.DefaultCameras
run_on_actor(getactors()[1], [==[
    -- services
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService  = game:GetService("UserInputService")
    local Workspace         = game:GetService("Workspace")

    -- module
    local GunModule = require(ReplicatedStorage.Modules.Items.Item.Gun)
    local original_get_shoot_look = GunModule.get_shoot_look

    -- settings
    local FOV_RADIUS = 60
    local FOV_RADIUS_SQ = FOV_RADIUS * FOV_RADIUS

    local TARGET_PARTS = {
        "head", "torso",
        "shoulder1", "shoulder2",
        "arm1", "arm2",
        "hip1", "hip2",
        "leg1", "leg2",
        "Sleeve", "Glove",
        "Boot"
    }

    local viewmodelsFolder = nil
    local camera = Workspace.CurrentCamera

    local function checkPart(part, mousePos, closestPart, closestDistSq)
        if not part or not part:IsA("BasePart") then 
            return closestPart, closestDistSq 
        end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then 
            return closestPart, closestDistSq 
        end

        local dx = screenPos.X - mousePos.X
        local dy = screenPos.Y - mousePos.Y
        local distSq = dx * dx + dy * dy

        if distSq <= FOV_RADIUS_SQ and distSq < closestDistSq then
            return part, distSq
        end

        return closestPart, closestDistSq
    end

    local function getClosestTargetToCursor()
        local closestPart, closestDistSq = nil, math.huge
        local mousePos = UserInputService:GetMouseLocation()

        if not viewmodelsFolder then
            viewmodelsFolder = Workspace:FindFirstChild("Viewmodels")
        end

        if viewmodelsFolder then
            for _, vm in ipairs(viewmodelsFolder:GetChildren()) do
                if vm.Name == "LocalViewmodel" or vm.Name ~= "Viewmodel" then continue end
                
                local torso = vm:FindFirstChild("torso")
                if torso and torso.Transparency == 1 then continue end

                for _, partName in ipairs(TARGET_PARTS) do
                    local part = vm:FindFirstChild(partName)
                    closestPart, closestDistSq = checkPart(part, mousePos, closestPart, closestDistSq)
                end
            end
        end

        for _, model in ipairs(Workspace:GetChildren()) do
            if not model:IsA("Model") then continue end

            local modelName = model.Name
            local targetChild = nil

            if modelName == "Drone" then
                targetChild = model:FindFirstChild("HumanoidRootPart")
            elseif modelName == "Claymore" then
                targetChild = model:FindFirstChild("Laser")
            elseif modelName == "ProximityAlarm" then
                targetChild = model:FindFirstChild("RedDot")
            elseif modelName == "StickyCamera" then
                targetChild = model:FindFirstChild("Cam")
            elseif modelName == "SignalDisruptor" then
                targetChild = model:FindFirstChild("Screen")
            end

            if targetChild then
                closestPart, closestDistSq = checkPart(targetChild, mousePos, closestPart, closestDistSq)
            end
        end

        for _, model in ipairs(Workspace:GetChildren()) do
            if not model:IsA("Model") then continue end
            
            local folder = model:FindFirstChildWhichIsA("Folder")
            if not folder then continue end
            
            local defaultCameras = folder:FindFirstChild("DefaultCameras")
            if not defaultCameras then continue end
            
            for _, defaultCam in ipairs(defaultCameras:GetChildren()) do
                if not defaultCam:IsA("Model") then continue end
                
                local cam = defaultCam:FindFirstChild("Dot")
                if cam then
                    closestPart, closestDistSq = checkPart(cam, mousePos, closestPart, closestDistSq)
                end
            end
        end

        return closestPart
    end

    GunModule.get_shoot_look = function(self)
        local originalCFrame = original_get_shoot_look(self)

        local targetPart = getClosestTargetToCursor()
        if targetPart then
            local weaponPos = originalCFrame.Position
            local direction = (targetPart.Position - weaponPos).Unit
            return CFrame.lookAt(weaponPos, weaponPos + direction)
        end

        return originalCFrame
    end

    print("w nigga")
]==])