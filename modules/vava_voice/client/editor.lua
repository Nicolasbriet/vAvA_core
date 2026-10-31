--[[
    vava_voice/client/editor.lua
    Rôle : éditeur des zones de voix pour le Conseil, ouvert depuis l'outil du Registre ou par commande. Le serveur
           accorde l'ouverture puis revérifie chaque action ; le client ne fait que montrer. Tant qu'il est ouvert,
           les zones proches sont dessinées en cylindres transparents (teinte selon l'effet) et l'aperçu suit les
           réglages en direct : la boucle par image ne vit que le temps de l'édition, chez le seul membre du Conseil.
           Un enregistrement à la fois (pas de double envoi) ; focus rendu si la ressource s'arrête éditeur ouvert.
           Liste propre à l'éditeur (1.3.0) : toutes les zones, reçues du serveur à l'ouverture (au seul membre qui
           l'ouvre), puis tenues à jour par ses propres actions et par les zones proches changées par un autre membre
           (abonnements de zone) ; une zone lointaine changée par un autre l'est à la réouverture.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua, client/zones.lua
]]

local type, pairs, sort, floor, tointeger, tostring = type, pairs, table.sort, math.floor, math.tointeger, tostring
local pcall, error = pcall, error
local CreateThread, Wait = CreateThread, Wait
local PlayerPedId, GetEntityCoords, DrawMarker = PlayerPedId, GetEntityCoords, DrawMarker

local core = VavaVoice.core
local nui, zones = VavaVoice.nui, VavaVoice.zones
local cfg = VavaVoice.config.zones
local RPC = VavaVoice.RPC
local DRAW_SQUARED = cfg.drawDistance * cfg.drawDistance

local editor = {}
VavaVoice.editor = editor

local open = false
local opening = false
-- enregistrement en cours : un second « Sceller » attend la réponse du premier
local saving = false
local canTeleport = false
-- aperçu : zone en cours de création (id nil) ou de modification, avec les réglages de l'interface
---@type table|nil
local preview = nil
-- zones connues de l'éditeur (numéro → zone vérifiée) : liste du serveur à l'ouverture, puis changements
---@type table<integer, table>
local known = {}

--- Remplace la liste de l'éditeur par celle du serveur.
---@param raw any
local function adopt(raw)
    known = {}
    if type(raw) ~= 'table' then return end
    for _, entry in pairs(raw) do
        local zone = zones.valid(entry)
        if zone then known[zone.id] = zone end
    end
end

---@return boolean
function editor.isOpen()
    return open
end

local function here()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

---@param multiplier number
---@return table color
local function colorOf(multiplier)
    if multiplier < 1 then return cfg.colors.quiet end
    if multiplier > 1 then return cfg.colors.loud end
    return cfg.colors.neutral
end

--- Zones pour l'interface, des plus proches aux plus lointaines, avec leur distance.
---@return table[]
local function listed()
    local origin = here()
    local out = {}
    for _, zone in pairs(known) do
        local dx, dy, dz = zone.x - origin.x, zone.y - origin.y, zone.z - origin.z
        out[#out + 1] = {
            id = zone.id, label = zone.label, radius = zone.radius, height = zone.height, multiplier = zone.multiplier,
            distance = floor((dx * dx + dy * dy + dz * dz) ^ 0.5 + 0.5),
        }
    end
    sort(out, function(a, b) return a.distance < b.distance or (a.distance == b.distance and a.id < b.id) end)
    return out
end

---@param zone table
---@param alpha integer
local function draw(zone, alpha)
    local color = colorOf(zone.multiplier)
    local diameter = zone.radius * 2.0
    DrawMarker(cfg.marker, zone.x, zone.y, zone.z - cfg.baseOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        diameter, diameter, zone.height + cfg.baseOffset, color[1], color[2], color[3], alpha, false, false, 2, false, nil, nil, false)
end

local function drawLoop()
    -- boucle par image justifiée : un marqueur se dessine à chaque image, et seulement éditeur ouvert
    while open do
        local origin = here()
        local editing = preview and preview.id
        for _, zone in pairs(known) do
            local dx, dy = zone.x - origin.x, zone.y - origin.y
            if zone.id ~= editing and dx * dx + dy * dy <= DRAW_SQUARED then draw(zone, cfg.alpha) end
        end
        if preview then draw(preview, cfg.selectedAlpha) end
        Wait(0)
    end
end

--- Réglages de l'interface, ramenés aux bornes.
---@param data table
---@return table
local function settingsOf(data)
    local function bounded(value, bounds)
        if type(value) ~= 'number' or value ~= value then return bounds.default end
        if value < bounds.min then return bounds.min end
        if value > bounds.max then return bounds.max end
        return value
    end
    local multiplier = cfg.defaultMultiplier
    for _, allowed in pairs(cfg.multipliers) do
        if data.multiplier == allowed then multiplier = allowed end
    end
    return { radius = bounded(data.radius, cfg.radius), height = bounded(data.height, cfg.height), multiplier = multiplier }
end

--- Résultat d'une RPC pour l'interface.
---@return table
local function answer(ok, success, result)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(result) } end
    return { ok = true, result = result }
end

function editor.close()
    if not open then return end
    open = false
    preview = nil
    nui.send('close')
    nui.setFocus(false)
end

--- Arrêt de la ressource : l'interface disparaît avec elle, seul le focus est à rendre (éditeur ouvert seulement).
function editor.release()
    if not open then return end
    open = false
    preview = nil
    nui.setFocus(false)
end

--- Demande l'ouverture au serveur (rien ne se passe sans le droit du Conseil).
function editor.open()
    if open or opening or not nui.isReady() or not core.characters.current() then return end
    opening = true
    local ok, success, data = core.rpc.call(RPC.EDITOR)
    opening = false
    if not ok or not success or type(data) ~= 'table' then return end
    adopt(data.zones)
    canTeleport = data.canTeleport == true
    open = true
    preview = nil
    nui.send('open', {
        zones = listed(), canTeleport = canTeleport,
        limits = {
            radius = cfg.radius, height = cfg.height, multipliers = cfg.multipliers,
            defaultMultiplier = cfg.defaultMultiplier, labelMax = cfg.labelMax, max = cfg.max,
            ranges = VavaVoice.config.ranges, baseOffset = cfg.baseOffset,
        },
    })
    nui.setFocus(true)
    CreateThread(drawLoop)
end

--- Les zones ont changé (décision du Conseil) : liste de l'interface à jour.
function editor.refresh()
    if open then nui.send('zones', { zones = listed() }) end
end

--- Zone proche reçue ou changée (abonnements de zone) : la liste de l'éditeur suit, même pour un changement fait par
--- un autre membre. S'éloigner d'une zone ne la retire pas de la liste.
---@param kind string  'enter' | 'change' | 'leave'
---@param raw any      la zone (enter, change)
function editor.track(kind, raw)
    if kind ~= 'enter' and kind ~= 'change' then return end
    local zone = zones.valid(raw)
    if not zone then return end
    known[zone.id] = zone
    editor.refresh()
end

--- Liste redemandée au serveur (une zone a disparu entre-temps : supprimée par un autre membre).
local function refetch()
    local ok, success, data = core.rpc.call(RPC.EDITOR)
    if not open or not ok or not success or type(data) ~= 'table' then return end
    adopt(data.zones)
    editor.refresh()
end

--- Après une réponse du serveur : liste de l'éditeur à jour (zone scellée ou supprimée), ou redemandée.
---@param result table  réponse pour l'interface
---@param removedId integer|nil  zone supprimée
local function follow(result, removedId)
    if result.ok then
        if removedId then
            known[removedId] = nil
        else
            local zone = zones.valid(result.result)
            if zone then known[zone.id] = zone end
        end
        editor.refresh()
    elseif result.error == 'unknown_zone' then
        CreateThread(refetch)
    end
end

-- Interface -------------------------------------------------------------------------------------------------------

nui.on('close', function()
    editor.close()
    return { ok = true }
end)

--- Commencer une zone : centrée sur le joueur, réglages par défaut.
nui.on('startNew', function()
    if not open then return { ok = false, error = 'closed' } end
    local center = here()
    preview = {
        x = center.x, y = center.y, z = center.z, radius = cfg.radius.default, height = cfg.height.default,
        multiplier = cfg.defaultMultiplier,
    }
    return { ok = true }
end)

--- Modifier une zone : son aperçu remplace son dessin.
nui.on('edit', function(data)
    local id = tointeger(data.id)
    local zone = open and id and known[id]
    if not zone then return { ok = false, error = 'unknown_zone' } end
    preview = { id = id, x = zone.x, y = zone.y, z = zone.z, radius = zone.radius, height = zone.height, multiplier = zone.multiplier, origin = zone }
    return { ok = true }
end)

--- Réglages modifiés dans l'interface : l'aperçu suit (« déplacer ici » : centré sur le joueur).
nui.on('preview', function(data)
    if not open or not preview then return { ok = false, error = 'closed' } end
    local settings = settingsOf(data)
    preview.radius, preview.height, preview.multiplier = settings.radius, settings.height, settings.multiplier
    -- une nouvelle zone garde le point où elle a été commencée ; une zone modifiée garde son centre, sauf déplacement
    local center = preview
    if data.moveHere == true then
        center = here()
    elseif preview.origin then
        center = preview.origin
    end
    preview.x, preview.y, preview.z = center.x, center.y, center.z
    return { ok = true }
end)

nui.on('cancel', function()
    preview = nil
    return { ok = true }
end)

--- Enregistrement demandé au serveur : modification si `id`, création sinon.
---@return table
local function store(data, settings, id)
    if id then
        return answer(core.rpc.call(RPC.UPDATE, id, data.label, settings.radius, settings.height, settings.multiplier, data.moveHere == true))
    end
    return answer(core.rpc.call(RPC.CREATE, data.label, settings.radius, settings.height, settings.multiplier))
end

nui.on('save', function(data)
    if not open then return { ok = false, error = 'closed' } end
    if saving then return { ok = false, error = 'busy' } end
    if type(data.label) ~= 'string' then return { ok = false, error = 'invalid_label' } end
    saving = true
    local called, result = pcall(store, data, settingsOf(data), tointeger(data.id))
    saving = false
    if not called then error(result, 0) end
    if result.ok then preview = nil end
    follow(result, nil)
    return result
end)

nui.on('delete', function(data)
    local id = tointeger(data.id)
    if not open or not id then return { ok = false, error = 'unknown_zone' } end
    local result = answer(core.rpc.call(RPC.DELETE, id))
    if result.ok then preview = nil end
    follow(result, id)
    return result
end)

nui.on('reach', function(data)
    local id = tointeger(data.id)
    if not open or not id then return { ok = false, error = 'unknown_zone' } end
    if not canTeleport then return { ok = false, error = 'forbidden' } end
    local result = answer(core.rpc.call(RPC.REACH, id))
    if not result.ok then follow(result, nil) end
    if result.ok then
        -- distances à jour une fois arrivé
        CreateThread(function()
            Wait(500)
            editor.refresh()
        end)
    end
    return result
end)
