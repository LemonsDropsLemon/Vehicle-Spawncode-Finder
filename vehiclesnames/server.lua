local lastForce, lastSave = {}, {}

local function norm(p) return (tostring(p):gsub('\\', '/')) end
local function clean(p) return (norm(p or ''):gsub('%.%.', '')) end

local resList

local function buildIndex()
    if resList then return resList end
    local idx = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        local path = name and GetResourcePath(name)
        if path then
            path = (norm(path):gsub('/+', '/'))
            local rel = path:match('.*/resources/(.+)$')
            if rel then
                rel = rel:gsub('^/+', ''):gsub('/+$', '')
                idx[#idx + 1] = { name = name, rel = rel, abs = path }
            end
        end
    end
    resList = idx
    return idx
end

local function split(s)
    local t = {}
    for part in s:gmatch('[^/]+') do t[#t + 1] = part end
    return t
end

local function under(rel, prefix)
    if prefix == '' then return rel end
    if rel == prefix then return '' end
    if rel:sub(1, #prefix + 1) == prefix .. '/' then return rel:sub(#prefix + 2) end
    return nil
end

local function listMetas(absPath, resName)
    local ok, list = pcall(function() return exports[GetCurrentResourceName()]:listMetas(absPath) end)
    if ok and type(list) == 'table' then return list end

    if not (io and io.popen) then return nil end
    local cmd
    if absPath:match('^%a:/') then
        cmd = ('dir /s /b "%s\\*.meta" 2>nul'):format((absPath:gsub('/', '\\')))
    else
        cmd = ('find "%s" -type f -name "*.meta" 2>/dev/null'):format(absPath)
    end
    local ok2, h = pcall(io.popen, cmd)
    if not ok2 or not h then return nil end
    local out = {}
    for line in h:lines() do
        line = norm(line):gsub('\r', '')
        local rel = under(line, absPath)
        if rel and rel ~= '' then out[#out + 1] = rel end
    end
    h:close()
    return out
end

local function globToPattern(g)
    g = g:gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0')
    g = g:gsub('%*%*/', '\1'):gsub('%*%*', '\2'):gsub('%*', '[^/]*')
    g = g:gsub('\1', '.-'):gsub('\2', '.*')
    return '^' .. g .. '$'
end

local function readManifest(res)
    return LoadResourceFile(res, 'fxmanifest.lua') or LoadResourceFile(res, '__resource.lua') or ''
end

local function collectCandidates(res, absPath)
    local files, seen, wild = {}, {}, {}
    local function add(f)
        f = f and norm(f):gsub('^%./', '')
        if not f or f == '' or seen[f] then return end
        seen[f] = true
        if f:find('%*') then wild[#wild + 1] = f else files[#files + 1] = f end
    end

    for i = 0, (GetNumResourceMetadata(res, 'data_file') or 0) - 1 do
        local a = GetResourceMetadata(res, 'data_file', i)
        local b = GetResourceMetadata(res, 'data_file_extra', i)
        if a == 'VEHICLE_METADATA_FILE' then add(b) elseif b == 'VEHICLE_METADATA_FILE' then add(a) end
    end

    local text = readManifest(res):gsub('%-%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', '')
    for path in text:gmatch('[\'"]([^\'"\n]-%.meta)[\'"]') do add(path) end

    local unresolved = {}
    local listing
    if #wild > 0 then
        listing = listMetas(absPath, res)
        for _, w in ipairs(wild) do
            local matched = false
            if listing then
                local pat = globToPattern(w)
                for _, f in ipairs(listing) do
                    if f:match(pat) then
                        matched = true
                        if not seen[f] then seen[f] = true; files[#files + 1] = f end
                    end
                end
            end
            if not matched then
                local simple = w:gsub('%*%*/', '')
                if not simple:find('%*') and not seen[simple] then
                    seen[simple] = true; files[#files + 1] = simple
                elseif not listing then
                    unresolved[#unresolved + 1] = w
                end
            end
        end
    end

    if #files == 0 then
        listing = listing or listMetas(absPath, res)
        if listing then for _, f in ipairs(listing) do add(f) end end
    end
    if #files == 0 then
        for _, f in ipairs({ 'vehicles.meta', 'data/vehicles.meta', 'meta/vehicles.meta', 'data/vehicle.meta' }) do add(f) end
    end
    return files, unresolved
end

local function parseCodes(data)
    local codes = {}
    local block = data:match('<InitDatas>(.-)</InitDatas>')
    if not block then return codes end
    for model in block:gmatch('<[Mm]odelName>%s*([^<%s]+)%s*</[Mm]odelName>') do codes[#codes + 1] = model end
    return codes
end

local function computeEntry(r)
    local files, unresolved = collectCandidates(r.name, r.abs)
    local all, seen, used, srcOf = {}, {}, {}, {}
    for _, f in ipairs(files) do
        local data = LoadResourceFile(r.name, f)
        if data then
            local codes = parseCodes(data)
            if #codes > 0 then
                used[#used + 1] = f
                for _, c in ipairs(codes) do
                    if not seen[c:lower()] then seen[c:lower()] = true; srcOf[c:lower()] = #used; all[#all + 1] = c end
                end
            end
        end
    end

    local entry = false
    if #all > 0 then
        table.sort(all, function(a, b) return a:lower() < b:lower() end)
        local srcs = {}
        for i, c in ipairs(all) do srcs[i] = srcOf[c:lower()] end
        entry = { resource = r.name, path = r.rel, files = used, codes = all, srcs = srcs }
    end

    local warns = {}
    for _, w in ipairs(unresolved) do
        warns[#warns + 1] = ('%s: could not expand wildcard "%s" (is server.js running?)'):format(r.name, w)
    end
    return entry, warns
end

local cache = {
    ver = 0, gen = 0, dirty = true, building = false,
    entries = {},
    results = nil, allow = {}, total = 0,
}

local sliceStart = 0
local function slice()
    if GetGameTimer() - sliceStart >= (Config.IndexBudgetMs or 8) then
        Wait(0)
        sliceStart = GetGameTimer()
    end
end

local function ensureIndex(force)
    while cache.building do Wait(0) end
    if force then cache.entries = {}; cache.gen = cache.gen + 1; cache.dirty = true end
    if not cache.dirty and cache.results then return end

    cache.building = true
    sliceStart = GetGameTimer()
    local gen = cache.gen
    local startedAt = GetGameTimer()

    local ok, err = pcall(function()
        local results, allow, total = {}, {}, 0
        for _, r in ipairs(buildIndex()) do
            local e = cache.entries[r.name]
            if not e then
                local entry, warns = computeEntry(r)
                e = { r = entry, w = warns, path = r.rel }
                if cache.gen == gen then cache.entries[r.name] = e end
                slice()
            end
            if e.r then
                results[#results + 1] = e.r
                allow[e.r.path] = true
                total = total + #e.r.codes
            end
        end
        table.sort(results, function(a, b) return a.resource:lower() < b.resource:lower() end)
        cache.results, cache.allow, cache.total = results, allow, total
        cache.ver = cache.ver + 1
        print(('[spawnfinder] indexed %d spawncodes in %d packs (%d ms)'):format(total, #results, GetGameTimer() - startedAt))
    end)

    cache.dirty = cache.gen ~= gen
    cache.building = false
    if not ok then error(err, 0) end
end

local function invalidate(name)
    resList = nil
    if type(name) == 'string' then cache.entries[name] = nil end
    cache.gen = cache.gen + 1
    cache.dirty = true
end

AddEventHandler('onResourceStart', invalidate)
AddEventHandler('onResourceStop', invalidate)
AddEventHandler('onResourceListRefresh', function() cache.entries = {}; invalidate() end)

AddEventHandler('playerDropped', function()
    local s = source
    lastForce[s], lastSave[s] = nil, nil
end)

local function browse(prefix)
    local folders, resources, fcount = {}, {}, {}

    local allow
    if Config.OnlyShowFoldersWithVehicles then
        local ok, err = pcall(ensureIndex, false)
        if ok then
            allow = cache.allow
        else
            print('[spawnfinder] could not build the vehicle index, showing all folders: ' .. tostring(err))
        end
    end

    for _, r in ipairs(buildIndex()) do
        local sub = (not allow or allow[r.rel]) and under(r.rel, prefix) or nil
        if sub and sub ~= '' then
            local parts = split(sub)
            if #parts > 1 then
                fcount[parts[1]] = (fcount[parts[1]] or 0) + 1
            else
                resources[#resources + 1] = { name = r.name, path = r.rel }
            end
        end
    end
    for name, count in pairs(fcount) do
        folders[#folders + 1] = { name = name, path = (prefix == '' and name or (prefix .. '/' .. name)), count = count }
    end
    table.sort(folders, function(a, b) return a.name:lower() < b.name:lower() end)
    table.sort(resources, function(a, b) return a.name:lower() < b.name:lower() end)
    return { path = prefix, folders = folders, resources = resources }
end

local function scan(prefix)
    ensureIndex(false)
    local results, total, warnings = {}, 0, {}
    for _, r in ipairs(cache.results) do
        if under(r.path, prefix) then
            results[#results + 1] = r
            total = total + #r.codes
        end
    end
    for _, e in pairs(cache.entries) do
        if #e.w > 0 and under(e.path, prefix) then
            for _, w in ipairs(e.w) do warnings[#warnings + 1] = w end
        end
    end
    table.sort(warnings)
    return { path = prefix, total = total, results = results, warnings = warnings }
end

RegisterCommand('spawnfinder', function(src)
    if src == 0 then return print('[spawnfinder] Run this in-game.') end
    TriggerClientEvent('spawnfinder:open', src)
end, false)

RegisterNetEvent('spawnfinder:browse', function(prefix)
    local src = source
    local ok, res = pcall(browse, clean(prefix))
    if ok then TriggerClientEvent('spawnfinder:browseResult', src, res)
    else print('[spawnfinder] browse error: ' .. tostring(res)); TriggerClientEvent('spawnfinder:error', src, tostring(res)) end
end)

RegisterNetEvent('spawnfinder:scan', function(prefix)
    local src = source
    local ok, res = pcall(scan, clean(prefix))
    if ok then TriggerClientEvent('spawnfinder:scanResult', src, res)
    else print('[spawnfinder] scan error: ' .. tostring(res)); TriggerClientEvent('spawnfinder:error', src, tostring(res)) end
end)

RegisterNetEvent('spawnfinder:index', function(ver, force)
    local src = source

    if force == true then
        local now = GetGameTimer()
        if lastForce[src] and now - lastForce[src] < 15000 then force = false else lastForce[src] = now end
    end

    local ok, err = pcall(ensureIndex, force == true)
    if not ok then
        print('[spawnfinder] index error: ' .. tostring(err))
        return TriggerClientEvent('spawnfinder:error', src, tostring(err))
    end
    if ver == cache.ver then
        return TriggerClientEvent('spawnfinder:indexChunk', src, { ver = cache.ver, same = true })
    end

    local results, ver2, total = cache.results, cache.ver, cache.total
    local batch, n, first = {}, 0, true
    local function flush(last)
        TriggerClientEvent('spawnfinder:indexChunk', src, {
            ver = ver2, first = first, last = last, results = batch, total = total,
        })
        batch, n, first = {}, 0, false
        if not last then Wait(0) end
    end
    for _, r in ipairs(results) do
        batch[#batch + 1] = r
        n = n + #r.codes
        if n >= 400 then flush(false) end
    end
    flush(true)
end)

RegisterNetEvent('spawnfinder:save', function(label, text)
    local src = source
    if not Config.EnableSave then return end
    if type(text) ~= 'string' or #text == 0 or #text > 2000000 then return end

    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < (Config.SaveCooldown or 10) * 1000 then return end
    lastSave[src] = now

    label = tostring(label or 'all'):sub(1, 60):gsub('[^%w_%-]', '_')
    if label == '' then label = 'all' end
    local file = ('exports/%s.txt'):format(label)
    SaveResourceFile(GetCurrentResourceName(), file, text, -1)
    TriggerClientEvent('spawnfinder:saved', src, GetCurrentResourceName() .. '/' .. file)
end)
