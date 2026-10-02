# Vehicle-Spawncode-Finder-Browser-Spawner
Spawncode finder

# Spawn Finder

A FiveM resource that finds the **spawncodes** inside your vehicle packs, so you don't have to open `vehicles.meta` files by hand.

Browse your server's resource folders in an in-game menu, pick a pack (or a whole folder of packs), and get a clean list of every model name defined in its vehicle metas. You can also search every pack at once, copy codes, and spawn a car to test it, all from the same menu.

---

## Installation

This is drag and drop, works on any framework.

very easy, drop it in your server, ensure its actually started (can be hot loaded) and skadoosh!, its on

---

## Features


- **Folder browser** - click through `[vehicles]` → `[Dept-Cars]` → `[LEO-Veh]` exactly as it sits on disk.
- **Reads the fxmanifest** - finds vehicle metas from `data_file 'VEHICLE_METADATA_FILE'` entries and any `.meta` path written in the manifest (`files {}` blocks, `__resource.lua`, etc.).
- **Handles nested metas** - wildcards like `data/**/vehicles.meta` and `data/*/vehicles.meta` are expanded against the real folder contents, so `pack/data/carname/vehicles.meta` is found as well as `pack/data/vehicles.meta`.
- **Only real vehicle metas** - a file only counts if it contains an `<InitDatas>` block, so `handling.meta`, `carvariations.meta`, etc. never produce phantom spawncodes.
- **Global search** - search across *every* pack from the first screen. Matches spawncode, pack name, folder path and `.meta` file path. Multiple words narrow the results.
- **One-click actions** - click a name to copy it, click the `▶` square to spawn it, or copy / save a whole list.
- **Optional folder filter** - hide folders that don't contain any vehicle metas.
- **Cached** - the index is built once and only rebuilt when resources start or stop.

---

## Requirements

- A FiveM server (Windows or Linux) with the default Lua 5.4 and Node.js script runtimes (both included in standard server builds).
- Vehicle packs that define their vehicles through a `vehicles.meta` file.

No dependencies on any framework (ESX, QBCore, etc.).

---

## Usage

Type **`/spawnfinder`** in-game in chat, or the f8 colsole.

### Browsing
- Click a folder to go inside; use the breadcrumb or **Up** to go back.
- **List** (on a folder) or **List this folder / List everything** shows every spawncode underneath it.
- Click a pack (resource) to list just that pack.

### Searching
Just start typing in the search box on the first screen.

| You type | It matches |
|---|---|
| `police` | spawncodes, pack names, folder paths and file paths containing "police" |
| `lspd cruiser` | results matching **both** words |
| `data/borneo/vehicles` | only the car(s) defined in that meta file |
| `leo-veh` | every pack inside a folder with that name |

### Results
- Click a **spawncode** to copy it.
- Click the **`▶` square** next to it to spawn the vehicle in front of you.
- **Copy all** / **Copy comma list** copy whatever is currently shown.
- **💾 Save** writes the current list to `exports/<name>.txt` inside the resource.
- **⟳** forces a rescan of all packs.

---

## Configuration

Everything is in `config.lua`:

```lua
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
```

---

## How it works

Lua can't list directories, so the resource combines a few FiveM features:

1. **Folder tree** - built from the server's resource registry (`GetResourcePath`), so the folders you navigate are the real ones.
2. **Finding metas** - for each resource it reads the manifest's `data_file` entries and every `.meta` path written in the manifest text.
3. **Wildcards** - `server.js` (Node) lists the `.meta` files inside a pack, and the manifest patterns are matched against that listing. If nothing is declared, every `.meta` in the pack is checked.
4. **Parsing** - `LoadResourceFile` reads each candidate and pulls the `<modelName>` values from the `<InitDatas>` block.
5. **Index** - results are cached on the server and sent to the menu in chunks so search is instant.

---

## File structure

```
spawnfinder/
├── fxmanifest.lua
├── config.lua      -- settings
├── client.lua      -- opens the menu, spawns vehicles
├── server.lua      -- folder tree, manifest/meta scanning, index cache
├── server.js       -- directory listing helper (Node)
├── ui/
│   └── index.html  -- the menu
└── exports/        -- saved lists end up here
```

---

## Limitations

- **Packs without a `vehicles.meta`** (only `.yft`/`.ytd` files in `stream/`) have nothing to read, so they won't show spawncodes.
- **Spawning needs the model to be available** - the pack's resource must be started, otherwise the menu tells you the model isn't available.
- **Large servers** - the first scan after a server start can take a few seconds and may briefly stall the server thread while it runs. After that the cached index is used.

---

## Security notes

This resource has **no permission checks by default**: every player can open the menu, spawn vehicles and copy spawncodes to their clipboard. If this is no issue to you, ignore this

### Things to be aware of:

- Anyone who can open the menu can spawn any vehicle model available on the server. Spawning is client-side.
- With `Config.OnlyShowFoldersWithVehicles = false`, the folder browser shows **every** folder and resource name on the server, scripts included (but only the folder names, nothng inside the folder, unless its a vehicle). Leave it `true` if you don't want players seeing your resource names.
- The **Save** button IF enabled in config (which by default it isnt) lets players write `.txt` files into `exports/`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Resource won't start | Run `refresh`, check the folder name matches your `ensure`, and read the server console for errors. |
| A folder shows nothing | With `OnlyShowFoldersWithVehicles = true`, folders without vehicle metas are hidden on purpose. Set it to `false` to see everything. |
| A pack shows a "could not expand wildcard" warning | `server.js` isn't running (Node didn't load it). Check the console for errors at startup. |
| A pack returns no spawncodes | Make sure its manifest references a `vehicles.meta` that contains an `<InitDatas>` block, then press **⟳** to rescan. |
| New pack isn't listed | Run `refresh`, start the pack, then press **⟳** (the index also rebuilds when a resource starts or stops). |
| "Model isn't available" when spawning | Start the pack's resource first. |

---

## Showcase
Main Page
<img width="774" height="841" alt="image" src="https://github.com/user-attachments/assets/7dd5dea2-65b2-48ca-b9f4-47b834ffe09d" />

Inside Of A Pack
<img width="769" height="823" alt="image" src="https://github.com/user-attachments/assets/4160b2ea-c512-41f0-a0e4-cf2cfb9a6202" />

Pressing List Spawncodes Of Said Pack
<img width="784" height="845" alt="image" src="https://github.com/user-attachments/assets/7e7e90b9-e34a-4eb0-a153-ef6b5ad33e0b" />

Pressing "List Everything" on the main page
<img width="785" height="846" alt="image" src="https://github.com/user-attachments/assets/800722af-c487-4379-ab8a-e321a5ba36a0" />

Searching "Misc"
<img width="787" height="843" alt="image" src="https://github.com/user-attachments/assets/2fd50f90-272e-42c8-a8ea-50a5d6ef0053" />

## Support

If you need ANY Help, little or large, join my discord and open a ticket, im happy to assit, and am open to bug reports! 

https://discord.gg/pQqHBjwTE5
