local open = false


local lastVeh
local function toast(msg) SendNUIMessage({ action = 'toast', msg = msg }) end

local function setOpen(state)
    open = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = state and 'open' or 'close', save = Config.EnableSave == true })
end

RegisterNetEvent('spawnfinder:open', function() setOpen(true) end)
RegisterNetEvent('spawnfinder:browseResult', function(data) SendNUIMessage({ action = 'browse', data = data }) end)
RegisterNetEvent('spawnfinder:scanResult', function(data) SendNUIMessage({ action = 'scan', data = data }) end)
RegisterNetEvent('spawnfinder:indexChunk', function(data) SendNUIMessage({ action = 'indexChunk', data = data }) end)
RegisterNetEvent('spawnfinder:error', function(msg) SendNUIMessage({ action = 'error', msg = msg }) end)
RegisterNetEvent('spawnfinder:saved', function(file) SendNUIMessage({ action = 'saved', file = file }) end)

RegisterNUICallback('browse', function(d, cb) TriggerServerEvent('spawnfinder:browse', d.path or ''); cb('ok') end)
RegisterNUICallback('scan',   function(d, cb) TriggerServerEvent('spawnfinder:scan', d.path or ''); cb('ok') end)
RegisterNUICallback('index',  function(d, cb) TriggerServerEvent('spawnfinder:index', tonumber(d.ver) or 0, d.force == true); cb('ok') end)
RegisterNUICallback('save',   function(d, cb)
    if Config.EnableSave then TriggerServerEvent('spawnfinder:save', d.label, d.text) end
    cb('ok')
end)
RegisterNUICallback('close',  function(_, cb) setOpen(false); cb('ok') end)

RegisterNUICallback('spawn', function(d, cb)
    cb('ok')
    local name = tostring(d.model or '')
    local model = joaat(name)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        return toast(('"%s" isn\'t available - is its resource started?'):format(name))
    end

    RequestModel(model)
    local start = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - start < 8000 do Wait(0) end
    if not HasModelLoaded(model) then return toast(('Timed out loading "%s"'):format(name)) end

    local ped = PlayerPedId()
    if Config.DeletePrevious and lastVeh and DoesEntityExist(lastVeh) then
        SetEntityAsMissionEntity(lastVeh, true, true)
        DeleteEntity(lastVeh)
    end

    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(veh)
    if Config.WarpIntoVehicle then SetPedIntoVehicle(ped, veh, -1) end
    SetModelAsNoLongerNeeded(model)
    lastVeh = veh
    toast('Spawned ' .. name)
end)
