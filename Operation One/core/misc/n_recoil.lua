--Workspace.Model.{Cabin Derelict Oilrig Mall }.DefaultCameras
run_on_actor(getactors()[1], [==[

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

-- MODULE
local GunModule = require(ReplicatedStorage.Modules.Items.Item.Gun)

-- CACHE ORIGINAL FUNCTIONS
local original_recoil_function = GunModule.recoil_function
local original_send_shoot       = GunModule.send_shoot
local original_input_render     = GunModule.input_render

local recoil_proxy_mt = {
    __index = function(t, key)
        local real_states = rawget(t, "__real_states")
        local state = real_states[key]
        if typeof(state) == "table" and state.get then
            if key == "recoil_up" then
                return { get = function()
                    return state:get() * 0.1
                end }
            elseif key == "recoil_side" then
                return { get = function()
                    return state:get() * 0
                end }
            end
        end
        return state
    end
}

local spread_firerate_proxy_mt = {
    __index = function(t, key)
        local real_states = rawget(t, "__real_states")
        local state = real_states[key]
        if typeof(state) == "table" and state.get then
            if key == "spread" then
                return { get = function()
                    return 0
                end }
            elseif key == "firerate" then
                return { get = function()
                    return 999
                end }
            end
        end
        return state
    end
}

local firerate_proxy_mt = {
    __index = function(t, key)
        local real_states = rawget(t, "__real_states")
        local state = real_states[key]
        if typeof(state) == "table" and state.get and key == "firerate" then
            return { get = function()
                return 999
            end }
        end
        return state
    end
}

local perfect_accuracy = { Value = 1 }


GunModule.recoil_function = function(self, owner)
    local real_states = self.states
    
    local proxy_states = { __real_states = real_states }
    setmetatable(proxy_states, recoil_proxy_mt)

    self.states = proxy_states
    original_recoil_function(self, owner)
    self.states = real_states
end


GunModule.send_shoot = function(self)
    local real_states   = self.states
    local real_accuracy = self.accuracy

    local proxy_states = { __real_states = real_states }
    setmetatable(proxy_states, spread_firerate_proxy_mt)

    self.states   = proxy_states
    self.accuracy = perfect_accuracy

    original_send_shoot(self)

    self.states   = real_states
    self.accuracy = real_accuracy
end


GunModule.input_render = function(self, ...)
    local real_states = self.states

    local proxy_states = { __real_states = real_states }
    setmetatable(proxy_states, firerate_proxy_mt)

    self.states = proxy_states
    original_input_render(self, ...)
    self.states = real_states
end


]==])