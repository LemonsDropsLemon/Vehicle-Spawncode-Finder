Config = {}

-- true  = the folder browser only shows folders/packs that contain vehicle metas (vehicles.meta with spawncodes)
-- false = show every folder and resource on the server (however, still only spawns/shows those with vehicle.metas, because well, its a vehicle spawncode finder :]
Config.OnlyShowFoldersWithVehicles = true

-- Spawning from the menu
Config.DeletePrevious  = true -- delete the last car spawned from this menu before spawning a new one
Config.WarpIntoVehicle = true -- put you in the driver seat

-- Saving results to exports/*.txt inside this resource
-- false = the Save buttons are hidden AND the server ignores save requests (recommended for live servers)
Config.EnableSave   = false
Config.SaveCooldown = 10 -- seconds a player must wait between saves (only matters if EnableSave = true)

-- Performance
Config.IndexBudgetMs = 8          -- max milliseconds of server time per tick spent building the index (lower = gentler, slower first build)
