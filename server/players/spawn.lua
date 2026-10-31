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
    Suites de la relecture sécurité (0.14.0) : seul un personnage encore chargé (session active sur lui, courant pour
    son joueur) est confirmé ; chaque ordre porte un numéro que la déclaration du client renvoie (une déclaration
    d'un ordre précédent ne compte pas) ; un ped jamais vu au point est relu toutes les spawn.confirm.lateCheckMs
    seulement ; au plus spawn.confirm.maxPerCheck confirmations par passage ; une erreur dans un passage garde le
    suivi et retente au passage suivant ; réglages bornés des deux côtés.
    Dépendances : shared/init.lua, shared/core/logger.lua, shared/core/hooks.lua, config/server.lua,
                  server/core/net.lua, server/core/zones.lua, server/players/accounts.lua, server/players/sync.lua,
                  server/players/playtime.lua
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
local accounts = vAvA.accounts
local sync = vAvA.sync
local playtime = vAvA.playtime
local cfg = vAvA.config.server.spawn
local confirmCfg = cfg.confirm
local log = vAvA.logger.create('spawn')

local HOOK_SPAWNED = 'core:character:spawned'

-- bornes des réglages spawn.confirm (relecture sécurité S-5) : une valeur démesurée ne désactive pas la confirmation
local MIN_CHECK_MS, MAX_CHECK_MS = 50, 5000
local MAX_RADIUS = 50
local MAX_GRACE_MS = 120000
local MAX_LATE_CHECK_MS = 60000
local MAX_PER_CHECK = 1024

local spawn = {}
vAvA.spawn = spawn

-- numéro du dernier ordre d'apparition envoyé (tous joueurs) : renvoyé par la déclaration du client, il la rattache à
-- son ordre ; repart à 1 après MAX_ORDER
spawn.MAX_ORDER = 0x7FFFFFFF
local lastOrder = 0

---@class vAvA.SpawnWatch
---@field point vAvA.SpawnPoint  point ordonné
---@field order integer          numéro de l'ordre (renvoyé par la déclaration du client)
---@field orderedAt integer      GetGameTimer de l'ordre
---@field nextReadAt integer     prochaine lecture du ped par un passage (espacée après l'avertissement)
---@field seenAt integer|nil     première lecture du ped au point depuis l'ordre
---@field claimed boolean        le client a déclaré son apparition
---@field warned boolean         ligne « jamais vu au point » déjà écrite pour cet ordre
---@field failed boolean         ligne d'erreur déjà écrite pour cet ordre

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

---@param value any
---@param low integer
---@param high integer
---@return boolean
local function isIntegerIn(value, low, high)
    return mathType(value) == 'integer' and value >= low and value <= high
end

--- Vérifie les réglages de la confirmation. Appelé par init.lua avant d'ouvrir les RPC : une config invalide
--- empêche le démarrage du core (comme celle du rate limiting). Bornés des deux côtés : un délai ou un rayon
--- démesuré reviendrait à ne plus rien vérifier.
---@return boolean ok
---@return string|nil err
function spawn.validateConfig()
    if type(confirmCfg) ~= 'table' then return false, 'config spawn.confirm absente' end
    local checkMs = confirmCfg.checkMs
    if not isIntegerIn(checkMs, MIN_CHECK_MS, MAX_CHECK_MS) then
        return false, ('config spawn.confirm.checkMs : entier de %d à %d attendu'):format(MIN_CHECK_MS, MAX_CHECK_MS)
    end
    if not isFinite(confirmCfg.radius) or confirmCfg.radius <= 0 or confirmCfg.radius > MAX_RADIUS then
        return false, ('config spawn.confirm.radius : nombre de plus de 0 à %d attendu'):format(MAX_RADIUS)
    end
    if not isIntegerIn(confirmCfg.graceMs, checkMs, MAX_GRACE_MS) then
        return false, ('config spawn.confirm.graceMs : entier de checkMs à %d attendu'):format(MAX_GRACE_MS)
    end
    if not isIntegerIn(confirmCfg.lateCheckMs, checkMs, MAX_LATE_CHECK_MS) then
        return false, ('config spawn.confirm.lateCheckMs : entier de checkMs à %d attendu'):format(MAX_LATE_CHECK_MS)
    end
    if not isIntegerIn(confirmCfg.maxPerCheck, 1, MAX_PER_CHECK) then
        return false, ('config spawn.confirm.maxPerCheck : entier de 1 à %d attendu'):format(MAX_PER_CHECK)
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

--- Vrai si le personnage est encore chargé : courant pour son joueur et session active sur lui. Un personnage en
--- déchargement (état 'unloading' : hooks et sauvegarde qui cèdent la main), déchargé ou dont le joueur est parti
--- n'est jamais confirmé (relecture sécurité S-1).
---@param character vAvA.Character
---@return boolean
local function isLoaded(character)
    if not sync.isCurrent(character) then return false end
    local session = accounts.get(character.source)
    return session ~= nil and session.state == 'active' and session.characterId == character.id
end

--- Apparition confirmée : état du personnage, temps de jeu, hook, zones proches. Revérifie d'abord que le
--- personnage est encore chargé (sinon le suivi est seulement oublié).
---@param character vAvA.Character
---@param forced boolean  confirmée sans déclaration du client
---@return boolean confirmed
local function confirm(character, forced)
    watches[character] = nil
    if not isLoaded(character) then return false end
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
    return true
end

--- Lecture du ped puis décision pour une apparition qui attend. Après l'avertissement « jamais vu au point », un
--- passage ne relit le ped que toutes les lateCheckMs (relecture réseau R-1) ; une déclaration le relit toujours.
---@param character vAvA.Character
---@param watch vAvA.SpawnWatch
---@param now integer
---@param readNow boolean  lecture même avant nextReadAt (déclaration du client)
---@return boolean confirmed
local function step(character, watch, now, readNow)
    if not watch.seenAt and (readNow or now >= watch.nextReadAt) then
        if spawn.inPlace(watch.point, net.positionOf(character.source), confirmCfg.radius) then
            watch.seenAt = now
        elseif watch.warned then
            watch.nextReadAt = now + confirmCfg.lateCheckMs
        end
    end
    local verdict = spawn.verdict(watch, now, confirmCfg.graceMs)
    if verdict == 'confirm' then
        return confirm(character, false)
    elseif verdict == 'force' then
        return confirm(character, true)
    elseif verdict == 'warn' then
        watch.warned = true
        watch.nextReadAt = now + confirmCfg.lateCheckMs
        -- compte et personnage : le numéro de joueur seul se redonne (relecture sécurité S-4)
        log.warn('joueur %d (compte #%s, personnage #%s) : ped jamais vu au point d\'apparition %d s après l\'ordre'
            .. ' (%s) : apparition non confirmée', character.source, tostring(character.accountId),
            tostring(character.id), confirmCfg.graceMs // 1000,
            watch.claimed and 'déclarée par son client' or 'rien déclaré par son client')
    end
    return false
end

local arm

--- Passage des apparitions qui attendent. Les personnages sont relevés avant le parcours : un hook appelé par une
--- confirmation peut redonner un ordre (nouveau suivi) pendant le passage. Au plus maxPerCheck confirmations par
--- passage (relecture réseau R-2) : les suivantes attendent le passage suivant.
local function tick()
    armed = false
    local due, count = {}, 0
    for character in pairs(watches) do
        count = count + 1
        due[count] = character
    end
    local now = GetGameTimer()
    local confirmed, cap = 0, confirmCfg.maxPerCheck
    for i = 1, count do
        if confirmed >= cap then break end
        local character = due[i]
        local watch = watches[character]
        if watch then
            if isLoaded(character) then
                local ok, result = xpcall(step, traceback, character, watch, now, false)
                if not ok then
                    -- suivi gardé, retenté au passage suivant (relecture sécurité S-6) ; une ligne par ordre
                    if not watch.failed then
                        watch.failed = true
                        log.error('joueur %d : confirmation d\'apparition en erreur (retentée) : %s', character.source,
                            tostring(result))
                    end
                elseif result then
                    confirmed = confirmed + 1
                end
            else
                -- personnage qui n'est plus chargé (parti, en déchargement, déchargé) : rien à confirmer
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
    lastOrder = lastOrder % spawn.MAX_ORDER + 1
    local order = lastOrder
    local sent, code = net.dispatch(vAvA.resourceName, EVENTS.SPAWN, character.source, net.RELIABLE, EVENTS.SPAWN, {
        model = withModel and cfg.models[character.sex] or nil,
        x = point.x, y = point.y, z = point.z, heading = point.heading, seq = order,
    })
    if not sent then
        sync.abandon(character, EVENTS.SPAWN, code)
        return false, code
    end
    local orderedAt = GetGameTimer()
    watches[character] = {
        point = { x = point.x, y = point.y, z = point.z, heading = point.heading }, order = order,
        orderedAt = orderedAt, nextReadAt = orderedAt, seenAt = nil, claimed = false, warned = false, failed = false,
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

--- Déclaration du client (RPC core:characters:spawned, avec le numéro de l'ordre exécuté) : retenue, puis le ped
--- est lu aussitôt. Elle ne confirme l'apparition que si le ped a été vu au point ; sinon le passage suivant le fera
--- dès qu'il y sera vu. Une déclaration sans ordre en attente, ou d'un autre ordre que celui qui attend (ordre
--- précédent arrivé en retard), ne change rien.
---@param character vAvA.Character
---@param order integer  numéro de l'ordre exécuté par le client
---@return boolean ok
---@return string|nil err  'not_ordered' : aucun ordre en attente sous ce numéro
function spawn.claim(character, order)
    if character.spawned then return true end
    local watch = watches[character]
    if not watch or watch.order ~= order then return false, 'not_ordered' end
    watch.claimed = true
    step(character, watch, GetGameTimer(), true)
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
