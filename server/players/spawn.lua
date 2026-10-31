--[[
    server/players/spawn.lua
    Rôle : ordres d'apparition et leur confirmation. Le serveur décide de la position et du modèle ; l'ordre est envoyé
           au seul joueur concerné (core.net, toujours fiable : il suit le chargement du personnage), qui l'exécute
           puis le déclare (RPC core:characters:spawned).
    Apparition confirmée par le serveur (0.14.0, T-139) : la déclaration du client ne suffit plus. Après chaque ordre,
    le serveur lit le ped du joueur (GetPlayerPed, GetEntityCoords, par core.net) toutes les spawn.confirm.checkMs,
    pour ces seuls joueurs, et ne tient l'apparition pour faite qu'après l'avoir vu au point ordonné (écart horizontal
    au plus spawn.confirm.radius) : aussitôt à la déclaration du client si le ped y a été vu, sinon d'office
    spawn.confirm.graceMs après l'ordre (`forced`). Jamais vu au point : une ligne de console, et le personnage reste
    non apparu jusqu'à ce qu'il y soit vu. character.spawned (temps de jeu, positions, envois de proximité, zones)
    et le hook core:character:spawned ne viennent que de cette confirmation.
    Dépendances : shared/init.lua, shared/core/logger.lua, shared/core/hooks.lua, config/server.lua,
                  server/core/net.lua, server/core/zones.lua, server/players/sync.lua, server/players/playtime.lua
]]

local type, pairs, next, tostring, xpcall = type, pairs, next, tostring, xpcall
local traceback = debug.traceback
local HUGE = math.huge
local mathType = math.type
local GetGameTimer, SetTimeout = GetGameTimer, SetTimeout

local EVENTS = vAvA.EVENTS
local hooks = vAvA.hooks
local net = vAvA.net
local zones = vAvA.zones
local sync = vAvA.sync
local playtime = vAvA.playtime
local cfg = vAvA.config.server.spawn
local confirmCfg = cfg.confirm
local log = vAvA.logger.create('spawn')

local HOOK_SPAWNED = 'core:character:spawned'

local spawn = {}
vAvA.spawn = spawn

---@class vAvA.SpawnWatch
---@field point vAvA.SpawnPoint  point ordonné
---@field orderedAt integer      GetGameTimer de l'ordre
---@field seenAt integer|nil     première lecture du ped au point depuis l'ordre
---@field claimed boolean        le client a déclaré son apparition
---@field warned boolean         ligne « jamais vu au point » déjà écrite pour cet ordre

-- apparitions qui attendent leur confirmation : personnage → suivi (un seul par personnage, remplacé par un nouvel ordre)
---@type table<vAvA.Character, vAvA.SpawnWatch>
local watches = {}
-- une seule échéance de lecture à la fois, posée seulement s'il reste une apparition à confirmer
local armed = false

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= HUGE and value ~= -HUGE
end

---@class vAvA.SpawnPoint
---@field x number
---@field y number
---@field z number
---@field heading number

---@param coords any
---@return vAvA.SpawnPoint|nil
local function normalize(coords)
    if type(coords) ~= 'table' then return nil end
    local heading = coords.heading or 0.0
    if not (isFinite(coords.x) and isFinite(coords.y) and isFinite(coords.z) and isFinite(heading)) then return nil end
    return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
end

--- Vérifie les réglages de la confirmation. Appelé par init.lua avant d'ouvrir les RPC : une config invalide
--- empêche le démarrage du core (comme celle du rate limiting).
---@return boolean ok
---@return string|nil err
function spawn.validateConfig()
    if type(confirmCfg) ~= 'table' then return false, 'config spawn.confirm absente' end
    if mathType(confirmCfg.checkMs) ~= 'integer' or confirmCfg.checkMs < 50 then
        return false, 'config spawn.confirm.checkMs : entier de 50 au moins attendu'
    end
    if not isFinite(confirmCfg.radius) or confirmCfg.radius <= 0 then
        return false, 'config spawn.confirm.radius : nombre positif attendu'
    end
    if mathType(confirmCfg.graceMs) ~= 'integer' or confirmCfg.graceMs < confirmCfg.checkMs then
        return false, 'config spawn.confirm.graceMs : entier au moins égal à checkMs attendu'
    end
    return true
end

--- Vrai si une position lue est au point ordonné : écart horizontal au plus `radius` (la hauteur ne compte pas, le
--- ped pouvant tomber du point).
---@param point vAvA.SpawnPoint
---@param coords { x: number, y: number }|nil  position lue par le serveur (nil : pas de ped)
---@param radius number
---@return boolean
function spawn.inPlace(point, coords, radius)
    if not coords then return false end
    local dx, dy = coords.x - point.x, coords.y - point.y
    return dx * dx + dy * dy <= radius * radius
end

--- Décision sur une apparition qui attend (règle pure) :
---   'confirm' : ped vu au point et apparition déclarée par le client ;
---   'force'   : ped vu au point, rien de déclaré, graceMs écoulées depuis l'ordre ;
---   'warn'    : ped jamais vu au point, graceMs écoulées, rien encore écrit pour cet ordre ;
---   'wait'    : sinon.
---@param watch vAvA.SpawnWatch
---@param now integer
---@param graceMs integer
---@return string
function spawn.verdict(watch, now, graceMs)
    local late = now - watch.orderedAt >= graceMs
    if not watch.seenAt then
        if late and not watch.warned then return 'warn' end
        return 'wait'
    end
    if watch.claimed then return 'confirm' end
    if late then return 'force' end
    return 'wait'
end

--- Apparition confirmée : état du personnage, temps de jeu, hook, zones proches.
---@param character vAvA.Character
---@param forced boolean  confirmée sans déclaration du client
local function confirm(character, forced)
    watches[character] = nil
    character.spawned = true
    playtime.begin(character)
    local src = character.source
    if forced then
        log.warn('joueur %d : apparition confirmée d\'office (ped vu au point, rien déclaré par son client en %d s)',
            src, confirmCfg.graceMs // 1000)
    end
    hooks.runAfter(HOOK_SPAWNED, {
        source = src, accountId = character.accountId, characterId = character.id, forced = forced,
    })
    -- zones proches envoyées tout de suite, sans attendre le passage suivant (sauf si un hook a déjà redonné un ordre)
    if character.spawned then zones.refreshPlayer(src) end
end

--- Lecture du ped puis décision pour une apparition qui attend.
---@param character vAvA.Character
---@param watch vAvA.SpawnWatch
---@param now integer
local function step(character, watch, now)
    if not watch.seenAt and spawn.inPlace(watch.point, net.positionOf(character.source), confirmCfg.radius) then
        watch.seenAt = now
    end
    local verdict = spawn.verdict(watch, now, confirmCfg.graceMs)
    if verdict == 'confirm' then
        confirm(character, false)
    elseif verdict == 'force' then
        confirm(character, true)
    elseif verdict == 'warn' then
        watch.warned = true
        log.warn('joueur %d : ped jamais vu au point d\'apparition %d s après l\'ordre (%s) : apparition non confirmée',
            character.source, confirmCfg.graceMs // 1000,
            watch.claimed and 'déclarée par son client' or 'rien déclaré par son client')
    end
end

local arm

--- Passage des apparitions qui attendent. Les personnages sont relevés avant le parcours : un hook appelé par une
--- confirmation peut redonner un ordre (nouveau suivi) pendant le passage.
local function tick()
    armed = false
    local due, count = {}, 0
    for character in pairs(watches) do
        count = count + 1
        due[count] = character
    end
    local now = GetGameTimer()
    for i = 1, count do
        local character = due[i]
        local watch = watches[character]
        if watch then
            if sync.isCurrent(character) then
                local ok, err = xpcall(step, traceback, character, watch, now)
                if not ok then
                    watches[character] = nil
                    log.error('joueur %d : confirmation d\'apparition en erreur : %s', character.source, tostring(err))
                end
            else
                -- personnage qui n'est plus celui de son joueur (parti, déchargé) : rien à confirmer
                watches[character] = nil
            end
        end
    end
    arm()
end

arm = function()
    if armed or next(watches) == nil then return end
    armed = true
    SetTimeout(confirmCfg.checkMs, tick)
end

---@param character vAvA.Character
---@param point vAvA.SpawnPoint
---@param withModel boolean
---@return boolean ok
---@return string|nil err  envoi impossible : le joueur est déconnecté avec un message clair (sync.abandon)
local function send(character, point, withModel)
    -- position non échantillonnée et temps de jeu suspendu tant que le serveur n'a pas confirmé
    playtime.pause(character)
    character.spawned = false
    watches[character] = nil
    local sent, code = net.dispatch(vAvA.resourceName, EVENTS.SPAWN, character.source, net.RELIABLE, EVENTS.SPAWN, {
        model = withModel and cfg.models[character.sex] or nil,
        x = point.x, y = point.y, z = point.z, heading = point.heading,
    })
    if not sent then
        sync.abandon(character, EVENTS.SPAWN, code)
        return false, code
    end
    watches[character] = {
        point = { x = point.x, y = point.y, z = point.z, heading = point.heading },
        orderedAt = GetGameTimer(), seenAt = nil, claimed = false, warned = false,
    }
    arm()
    return true
end

--- Première apparition après sélection : dernière position connue, sinon point par défaut.
---@param character vAvA.Character
function spawn.forCharacter(character)
    send(character, character.position or cfg.defaultPoint, true)
end

--- Réapparition ou téléportation décidée par le serveur (soins, propriétés…). Sans coordonnées : dernière
--- position connue.
---@param character vAvA.Character
---@param coords? vAvA.SpawnPoint
---@return boolean ok
---@return string|nil err
function spawn.at(character, coords)
    local point
    if coords == nil then
        point = character.position or cfg.defaultPoint
    else
        point = normalize(coords)
        if not point then return false, 'invalid_coords' end
    end
    return send(character, point, false)
end

--- Déclaration du client (RPC core:characters:spawned) : retenue, puis le ped est lu aussitôt. Elle ne confirme
--- l'apparition que si le ped a été vu au point ; sinon le passage suivant le fera dès qu'il y sera vu. Une
--- déclaration sans ordre en attente ne change rien.
---@param character vAvA.Character
---@return boolean ok
---@return string|nil err  'not_ordered' : aucun ordre en attente
function spawn.claim(character)
    if character.spawned then return true end
    local watch = watches[character]
    if not watch then return false, 'not_ordered' end
    watch.claimed = true
    step(character, watch, GetGameTimer())
    return true
end

--- Oublie l'apparition en attente d'un personnage (déchargement).
---@param character vAvA.Character
function spawn.forget(character)
    watches[character] = nil
end

--- Nombre d'apparitions qui attendent leur confirmation (essais, diagnostic).
---@return integer
function spawn.pendingCount()
    local count = 0
    for _ in pairs(watches) do count = count + 1 end
    return count
end
