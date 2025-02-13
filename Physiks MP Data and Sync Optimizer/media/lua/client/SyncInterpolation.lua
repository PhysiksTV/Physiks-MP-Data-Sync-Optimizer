--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/


-- LAST HOPE ROLEPLAY PERFORMANCE ENHANCER! 
-- Optimizes network and entity synchronization for Project Zomboid dedicated servers
--Fixes: 02/03/25 Seemed to be teleporting happening | Re-adjusted Interpolation for smoother in and out of view transitions.

print("Initializing SyncInterpolation...")

require("shared.PlayerSyncShared")
require("CheckInitialization")

SyncInterpolation = SyncInterpolation or {}

if not PlayerSync or not PlayerSync.StateKeys then
    print("ERROR: PlayerSync is not initialized.")
    return
end

-- Ensure PlayerSync is properly initialized
PlayerSync = PlayerSync or {}
PlayerSync.StateKeys = PlayerSync.StateKeys or {
    position = true,
    health = true,
    animation = true,
}
PlayerSync.Thresholds = PlayerSync.Thresholds or {
    position = 0.1,
    health = 0,
    animation = 0,
}

ZombieSync = ZombieSync or {}
ZombieSync.StateKeys = { position = true, health = true, animation = true }

VehicleSync = VehicleSync or {}
VehicleSync.StateKeys = { position = true, speed = true, health = true }

local proximityRange = 20

if not Events then
    error("ERROR: Events system is not initialized.")
end

Events.OnServerCommand.Add(function(module, command, args)
    if not args then return end
    
    if module == "PlayerSync" then
        if command == "Ping" and args.sender then
            sendServerCommand("PlayerSync", "Pong", {}, args.sender)
        elseif command == "BatchUpdate" and args.data and args.sender then
            local unpackedState = PlayerSync.bitUnpackState(args.data)
            if unpackedState then
                local timestamp = getTimestampMs()
                local sender = args.sender
                for _, otherPlayer in ipairs(getOnlinePlayers() or {}) do
                    if otherPlayer and otherPlayer ~= sender then
                        local distance = PlayerSync.calculateDistance(sender:getX(), sender:getY(), otherPlayer:getX(), otherPlayer:getY())
                        if distance <= proximityRange then
                            sendServerCommand("PlayerSync", "UpdateState", {
                                username = sender:getUsername(),
                                data = args.data,
                                timestamp = timestamp,
                            }, otherPlayer)
                        end
                    end
                end
            else
                print("WARNING: Invalid or missing player state in BatchUpdate.")
            end
        end
    elseif module == "ZombieSync" and command == "BatchUpdate" and args.data then
        for zombieID, state in pairs(ZombieSync.bitUnpackState(args.data) or {}) do
            print("Updating zombie state for ID: " .. zombieID)
        end
    elseif module == "VehicleSync" and command == "BatchUpdate" and args.data then
        for vehicleID, state in pairs(VehicleSync.bitUnpackState(args.data) or {}) do
            print("Updating vehicle state for ID: " .. vehicleID)
        end
    end
end)

function PlayerSync.bitUnpackState(data)
    if not data then return nil end
    local success, result = pcall(function()
        return loadstring("return " .. data)()
    end)
    if success then
        return result
    else
        print("ERROR: Failed to unpack state - " .. tostring(result))
        return nil
    end
end

function getTimestampMs()
    return math.floor(os.clock() * 1000)
end

print("PlayerSyncShared.lua Loaded Successfully")

-- SyncInterpolation Logic
if isServer() then return end -- Ensure this file executes only on the client

SyncInterpolation = SyncInterpolation or {}
SyncInterpolation.history = {}
SyncInterpolation.maxHistorySize = 10
SyncInterpolation.teleportThreshold = 3.0
SyncInterpolation.smoothingFactor = 0.1


if not SyncInterpolation or not SyncInterpolation.apply then
    log("error", "SyncInterpolation is missing or not loaded!")
end

function SyncInterpolation.apply(player, state, latency)
    SyncInterpolation.interpolatePosition(player, state.position, latency)
    SyncInterpolation.adjustAnimation(player, state.animation, latency)
end

function SyncInterpolation.interpolatePosition(player, targetPosition, latency)
    local id = player:getOnlineID()
    SyncInterpolation.history[id] = SyncInterpolation.history[id] or {}
    local history = SyncInterpolation.history[id]

    local currentX, currentY = player:getX(), player:getY()
    local distance = math.sqrt((targetPosition.x - currentX)^2 + (targetPosition.y - currentY)^2)

    if distance > SyncInterpolation.teleportThreshold then
        player:setX(currentX + (targetPosition.x - currentX) * SyncInterpolation.smoothingFactor)
        player:setY(currentY + (targetPosition.y - currentY) * SyncInterpolation.smoothingFactor)
    end

    table.insert(history, {x = targetPosition.x, y = targetPosition.y, time = os.clock()})
    if #history > SyncInterpolation.maxHistorySize then
        table.remove(history, 1)
    end
end


function SyncInterpolation.adjustAnimation(player, animation, latency)
    local animPlayer = player:getAnimationPlayer()
    if animPlayer then
        if animPlayer:getCurrentAnimation() ~= animation then
            animPlayer:playAnimation(animation)
        end
    else
        print("WARNING: AnimationPlayer is invalid for player:", player)
    end
end

Events.OnTick.Add(function()
    for playerID, history in pairs(SyncInterpolation.history) do
        if #history > 0 then
            local player = getPlayerByOnlineID(playerID)
            if player then
                SyncInterpolation.apply(player, {position = history[#history]}, 0)
            end
        end
    end
end)

print("SyncInterpolation.lua Loaded Successfully")



--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/
