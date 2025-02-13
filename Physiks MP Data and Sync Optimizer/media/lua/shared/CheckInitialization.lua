--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/


-- LAST HOPE ROLEPLAY PERFORMANCE ENHANCER! 
-- Optimizes network and entity synchronization for Project Zomboid dedicated servers


local success, err = pcall(function()
    require("shared.PlayerSyncShared")
end)

if not success then
    print("ERROR: " .. err)
    return
end

success, err = pcall(function()
    require("shared.SyncInterpolation")
end)

if not success then
    print("ERROR: " .. err)
    return
end

print("DataSync initialized successfully.")



--__________.__                 .__ __            
--\______   \  |__ ___.__. _____|__|  | __  ______
 --|     ___/  |  <   |  |/  ___/  |  |/ / /  ___/
 --|    |   |   Y  \___  |\___ \|  |    <  \___ \ 
-- |____|   |___|  / ____/____  >__|__|_ \/____  >
 --              \/\/         \/        \/     \/
