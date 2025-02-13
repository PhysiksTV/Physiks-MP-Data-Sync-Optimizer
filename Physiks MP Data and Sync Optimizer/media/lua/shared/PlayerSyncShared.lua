--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\\___ \\|  |    <  \\___ \\ 
-- |____|   |___|  / ____/____  >__|__|_ \\/____  >
 --              \\/\\/         \\/        \\/     \\/

-- LAST HOPE ROLEPLAY PERFORMANCE ENHANCER! 
-- Optimizes network and entity synchronization for Project Zomboid dedicated servers


require "CheckInitialization"

-- Ensure PlayerSync is initialized
PlayerSync = PlayerSync or {}
PlayerSync.StateKeys = {
    position = true,
    health = true,
    animation = true,
}
PlayerSync.Thresholds = {
    position = 0.1,
    health = 0,
    animation = 0,
}

-- Ensure bitUnpackState is defined
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

-- Initialize ZombieSync and VehicleSync
ZombieSync = {}
ZombieSync.StateKeys = { position = true, health = true, animation = true }

VehicleSync = {}
VehicleSync.StateKeys = { position = true, speed = true, health = true }

local proximityRange = 20

if not Events then
    error("ERROR: Events system is not initialized.")
end

-- Function to calculate distance between two points
function PlayerSync.calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Function to pack player state into a binary format
function PlayerSync.bitPackState(player)
    local packedData = {}
    table.insert(packedData, player:getX())
    table.insert(packedData, player:getY())
    table.insert(packedData, player:getHealth())
    table.insert(packedData, player:getAnimation())
    return packedData
end

-- Function to unpack player state from binary format
function PlayerSync.bitUnpackState(packedData)
    return {
        x = packedData[1],
        y = packedData[2],
        health = packedData[3],
        animation = packedData[4],
    }
end

-- Function to pack zombie state into a binary format
function ZombieSync.bitPackState(zombie)
    local packedData = {}
    table.insert(packedData, zombie:getX())
    table.insert(packedData, zombie:getY())
    table.insert(packedData, zombie:getHealth())
    table.insert(packedData, zombie:getAnimation())
    return packedData
end

-- Function to unpack zombie state from binary format
function ZombieSync.bitUnpackState(packedData)
    return {
        x = packedData[1],
        y = packedData[2],
        health = packedData[3],
        animation = packedData[4],
    }
end

-- Function to pack vehicle state into a binary format
function VehicleSync.bitPackState(vehicle)
    local packedData = {}
    table.insert(packedData, vehicle:getX())
    table.insert(packedData, vehicle:getY())
    table.insert(packedData, vehicle:getSpeed())
    table.insert(packedData, vehicle:getHealth())
    return packedData
end

-- Function to unpack vehicle state from binary format
function VehicleSync.bitUnpackState(packedData)
    return {
        x = packedData[1],
        y = packedData[2],
        speed = packedData[3],
        health = packedData[4],
    }
end

-- Function to get a Zombie entity by its ID
function getZombieByID(zombieID)
    local zombieList = getZombieManager():getZombies()  -- Get the list of all zombies
    for _, zombie in ipairs(zombieList) do
        if zombie:getID() == zombieID then
            return zombie
        end
    end
    return nil  -- Return nil if the zombie is not found
end

-- Function to get a Vehicle entity by its ID
function getVehicleByID(vehicleID)
    local vehicleList = getVehicleManager():getVehicles()  -- Get the list of all vehicles
    for _, vehicle in ipairs(vehicleList) do
        if vehicle:getID() == vehicleID then
            return vehicle
        end
    end
    return nil  -- Return nil if the vehicle is not found
end

-- Dummy function for timestamp
function getTimestampMs()
    return os.time() * 1000  -- Returns current time in milliseconds
end

-- Command handling for PlayerSync
Events.OnServerCommand.Add(function(module, command, args)
    if module == "PlayerSync" then
        if command == "Ping" then
            if args and args.sender then
                sendServerCommand("PlayerSync", "Pong", {}, args.sender)
            else
                print("WARNING: Received Ping command with nil sender.")
            end
        elseif command == "BatchUpdate" then
            if args and args.data and args.sender then
                local packedData = args.data
                local unpackedState = PlayerSync.bitUnpackState(packedData)
                if unpackedState then
                    local timestamp = getTimestampMs()
                    local sender = args.sender
                    for _, otherPlayer in ipairs(getOnlinePlayers() or {}) do
                        if otherPlayer and otherPlayer ~= sender then
                            local distance = PlayerSync.calculateDistance(sender:getX(), sender:getY(),
                                                                          otherPlayer:getX(), otherPlayer:getY())
                            if distance <= proximityRange then
                                sendServerCommand("PlayerSync", "UpdateState", {
                                    username = sender:getUsername(),
                                    data = packedData,
                                    timestamp = timestamp,
                                }, otherPlayer)
                            end
                        end
                    end
                else
                    print("WARNING: Invalid or missing player state in BatchUpdate.")
                end
            else
                print("WARNING: Received BatchUpdate command with invalid arguments.")
            end
        end
    elseif module == "ZombieSync" then
        if command == "BatchUpdate" then
            if args and args.data and args.zombieID then
                local packedData = args.data
                local zombieState = ZombieSync.bitUnpackState(packedData)
                if zombieState then
                    local zombieID = args.zombieID
                    local zombie = getZombieByID(zombieID)
                    if zombie then
                        -- Update zombie properties based on unpacked state
                        zombie:setX(zombieState.x)
                        zombie:setY(zombieState.y)
                        zombie:setHealth(zombieState.health)
                        zombie:setAnimation(zombieState.animation)
                        print("Updated zombie state for ID: " .. zombieID)
                    else
                        print("WARNING: Zombie ID " .. zombieID .. " not found.")
                    end
                else
                    print("WARNING: Invalid or missing zombie state in BatchUpdate.")
                end
            else
                print("WARNING: Received BatchUpdate command with invalid arguments.")
            end
        end
    elseif module == "VehicleSync" then
        if command == "BatchUpdate" then
            if args and args.data and args.vehicleID then
                local packedData = args.data
                local vehicleState = VehicleSync.bitUnpackState(packedData)
                if vehicleState then
                    local vehicleID = args.vehicleID
                    local vehicle = getVehicleByID(vehicleID)
                    if vehicle then
                        -- Update vehicle properties based on unpacked state
                        vehicle:setX(vehicleState.x)            -- Set new X position
                        vehicle:setY(vehicleState.y)            -- Set new Y position
                        vehicle:setHealth(vehicleState.health)  -- Set new health
                        vehicle:setSpeed(vehicleState.speed)    -- Set new speed
                        print("Updated vehicle state for ID: " .. vehicleID)
                    else
                        print("WARNING: Vehicle ID " .. vehicleID .. " not found.")
                    end
                else
                    print("WARNING: Invalid or missing vehicle state in BatchUpdate.")
                end
            else
                print("WARNING: Received BatchUpdate command with invalid arguments.")
            end
        end
    end
end)

print("PlayerSyncShared.lua Loaded Successfully")


--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/
