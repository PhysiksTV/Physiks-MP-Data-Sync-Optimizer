
--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/


-- LAST HOPE ROLEPLAY PERFORMANCE ENHANCER! 
-- Optimizes network and entity synchronization for Project Zomboid dedicated servers

-- Initialization and Dependency Checks !Physiks!
-- Client-side player synchronization.

if not isClient() then return end  

local function log(level, message)
    if level == "error" then
        print("ERROR: " .. message)
    elseif level == "warning" then
        print("WARNING: " .. message)
    elseif level == "info" then
        print("INFO: " .. message)
    end
end

PlayerSync = PlayerSync or {}
PlayerSync.StateKeys = PlayerSync.StateKeys or {}
PlayerSync.Thresholds = PlayerSync.Thresholds or {}

local latency = 0
local lastPingTime = os.clock()
local lastKnownState = {}
local pendingUpdates = {}
local updateCooldown = 0
local updateInterval = 0.1 -- 100ms updates
local proximityRange = 20 -- Proximity range for frequent updates

log("info", "PlayerSyncClient Initialized")

local function getPlayerByUsername(username)
    for _, player in ipairs(getOnlinePlayers()) do
        if player:getUsername() == username then
            return player
        end
    end
    return nil
end

function PlayerSync.bitUnpackState(data)
    local success, result = pcall(function()
        return load("return " .. data)()
    end)
    if success then
        return result
    else
        log("error", "Failed to unpack state: " .. tostring(result))
        return {}
    end
end

function ZombieSync.bitUnpackState(data)
    return PlayerSync.bitUnpackState(data)
end

function VehicleSync.bitUnpackState(data)
    return PlayerSync.bitUnpackState(data)
end

local function onServerCommand(module, command, args)
    if module == "PlayerSync" then
        if command == "Pong" then
            latency = (os.clock() - lastPingTime) / 2
            log("info", "Latency updated: " .. latency)
        elseif command == "UpdateState" then
            local targetPlayer = getPlayerByUsername(args.username)
            if targetPlayer then
                local unpackedState = PlayerSync.bitUnpackState(args.data)
                SyncInterpolation.apply(targetPlayer, unpackedState, latency)
            else
                log("error", "Target player not found for username: " .. args.username)
            end
        end
    elseif module == "ZombieSync" and command == "BatchUpdate" then
        local unpackedZombieState = ZombieSync.bitUnpackState(args.data)
        for zombieID, state in pairs(unpackedZombieState) do
            local zombie = getWorld():getZombie(zombieID)
            if zombie then
                zombie:setX(state.position.x)
                zombie:setY(state.position.y)
                zombie:setHealth(state.health)
                zombie:setAnimation(state.animation)
            else
                log("warning", "Zombie ID not found: " .. zombieID)
            end
        end
    elseif module == "VehicleSync" and command == "BatchUpdate" then
        local unpackedVehicleState = VehicleSync.bitUnpackState(args.data)
        for vehicleID, state in pairs(unpackedVehicleState) do
            local vehicle = getWorld():getVehicle(vehicleID)
            if vehicle then
                vehicle:setX(state.position.x)
                vehicle:setY(state.position.y)
                vehicle:setSpeed(state.speed)
                vehicle:setHealth(state.health)
            else
                log("warning", "Vehicle ID not found: " .. vehicleID)
            end
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- Measure latency using OnTick
Events.OnTick.Add(function()
    if os.clock() - lastPingTime >= 1 then
        lastPingTime = os.clock()
        sendClientCommand("PlayerSync", "Ping", {})
    end
end)

-- Player state tracking
if Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(function(player)
        if player:isLocalPlayer() then
            local currentAnimation = nil
            local animationPlayer = player:getAnimationPlayer()
            if animationPlayer and animationPlayer.getCurrentAnimation then
                local success, result = pcall(animationPlayer.getCurrentAnimation, animationPlayer)
                if success then
                    currentAnimation = result
                else
                    log("warning", "Error retrieving current animation: " .. result)
                end
            else
                log("warning", "AnimationPlayer is invalid or missing getCurrentAnimation method.")
            end

            local currentState = {
                position = { x = player:getX(), y = player:getY() },
                animation = currentAnimation,
                health = player:getBodyDamage():getOverallBodyHealth(),
            }

            for key, value in pairs(currentState) do
                if PlayerSync.StateKeys[key] then
                    local threshold = (PlayerSync.Thresholds[key]) or 0
                    if math.abs(value - (lastKnownState[key] or 0)) > threshold then
                        pendingUpdates[key] = value
                        lastKnownState[key] = value
                    end
                else
                    log("warning", "Missing key in PlayerSync.StateKeys: " .. key)
                end
            end

            -- Adjust update interval based on proximity to other players
            local closestDistance = math.huge
            for _, otherPlayer in ipairs(getOnlinePlayers()) do
                if otherPlayer ~= player then
                    local distance = PlayerSync.calculateDistance(player:getX(), player:getY(), otherPlayer:getX(), otherPlayer:getY())
                    closestDistance = math.min(closestDistance, distance)
                end
            end
            updateInterval = (closestDistance <= proximityRange) and 0.1 or (closestDistance > 0 and 0.5 or 1.0)
        end
    end)
else
    log("error", "Events.OnPlayerUpdate is nil! Check if it's properly initialized.")
end

-- Send updates to the server
Events.OnTick.Add(function()
    if updateCooldown <= 0 and next(pendingUpdates) ~= nil then
        local packedState = PlayerSync.bitPackState(pendingUpdates)
        sendClientCommand("PlayerSync", "BatchUpdate", { data = packedState })
        pendingUpdates = {}
        updateCooldown = updateInterval
    else
        updateCooldown = updateCooldown - getGameTime():getDeltaSeconds()
    end
end)

log("info", "PlayerSyncClient.lua Loaded Successfully")










--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/
