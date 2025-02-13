--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/


-- LAST HOPE ROLEPLAY PERFORMANCE ENHANCER! 
-- Optimizes network and entity synchronization for Project Zomboid dedicated servers
--02/03/2025 Fixed Events for Proper Zomboid OnTick event than the ones I created on MY server I forgot about.  I made Java changes and forgot :)
--02/04/25 OnTick fixes

if not isServer() then return end

require "SyncInterpolation"
require "PlayerSync"

print("PlayerSyncShared.lua and SyncInterpolation.lua loaded successfully.")

local latency = 0
local lastPingTime = os.clock()
local lastKnownState = {}
local pendingUpdates = {}
local updateCooldown = 0
local updateInterval = 0.1
local proximityRange = 20

local function checkDependencies()
    if not PlayerSync then
        error("ERROR: PlayerSync is nil. Check PlayerSyncShared.lua.")
        return false
    end
    if not PlayerSync.StateKeys then
        error("ERROR: PlayerSync.StateKeys is nil. Check PlayerSyncShared.lua.")
        return false
    end
    if not PlayerSync.bitUnpackState then
        error("ERROR: PlayerSync.bitUnpackState is nil. Check PlayerSyncShared.lua.")
        return false
    end
    if not Events then
        error("ERROR: Events is nil. Ensure the event system is initialized.")
        return false
    end
    return true
end

if not checkDependencies() then return end
print("All dependencies checked and valid.")

Events.OnTick.Add(function()
    if os.clock() - lastPingTime >= 1 then
        lastPingTime = os.clock()
        sendClientCommand("PlayerSync", "Ping", {})
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module == "PlayerSync" then
        if command == "Pong" then
            latency = (os.clock() - lastPingTime) / 2
            print("Latency updated:", latency)
        elseif command == "BatchUpdate" then
            if args and args.data and args.sender then
                local packedData = args.data
                local sender = args.sender

                print("Received BatchUpdate from", sender:getUsername())

                local unpackedState = PlayerSync.bitUnpackState(packedData)
                if not unpackedState then
                    print("ERROR: Failed to unpack player state.")
                    return
                end

                for _, otherPlayer in ipairs(getOnlinePlayers()) do
                    if otherPlayer and otherPlayer ~= sender then
                        local distance = PlayerSync.calculateDistance(sender:getX(), sender:getY(),
                                                                      otherPlayer:getX(), otherPlayer:getY())
                        if distance <= proximityRange then
                            sendServerCommand("PlayerSync", "UpdateState", {
                                username = sender:getUsername(),
                                data = packedData,
                            }, otherPlayer)
                        end
                    end
                end
            else
                print("WARNING: Received BatchUpdate command with invalid arguments.")
            end
        end
    end
end)

Events.OnPlayerUpdate.Add(function(player)
    if player:isLocalPlayer() then
        local currentAnimation = nil
        local animationPlayer = player:getAnimationPlayer()

        if animationPlayer then
            local success, result = pcall(function() return animationPlayer:getCurrentAnimation() end)
            if success then
                currentAnimation = result
            else
                print("WARNING: Error retrieving current animation:", result)
            end
        else
            print("WARNING: AnimationPlayer is invalid or missing.")
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
                print("WARNING: Missing key in PlayerSync.StateKeys -", key)
            end
        end
    end
end)

Events.OnTick.Add(function()
    if updateCooldown <= 0 and next(pendingUpdates) ~= nil then
        local packedState = PlayerSync.bitPackState(pendingUpdates)
        if not packedState then
            print("ERROR: Failed to pack player state.")
            return
        end
        sendServerCommand("PlayerSync", "BatchUpdate", { data = packedState })
        pendingUpdates = {}
        updateCooldown = updateInterval
    else
        updateCooldown = updateCooldown - getGameTime():getDeltaSeconds()
    end
end)

print("PlayerSyncServer.lua Loaded Successfully")





--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/
