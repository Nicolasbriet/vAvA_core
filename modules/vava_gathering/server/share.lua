--[[
    vava_gathering/server/share.lua
    Rôle : les zones de récolte partagées avec les seuls joueurs proches, par les abonnements de zone du core
           (vAvA_core ≥ 0.11.0, 1.6.0) : une zone du core par zone de récolte (nom local = id de la zone ; cercle qui
           englobe ses nœuds au sol ; marge = portée des props + streaming.subscribeSlack, pour que l'état soit là
           avant les props). État : `zone` → { band, scarred }, `n:<nœud>` → charges (shared/zonestate.lua). Chaque
           changement part aux seuls joueurs qui suivent la zone, regroupé par le core avec les autres changements du
           même tour (une récolte : zone et nœud en une différence). Une déclaration refusée est écrite en console
           (une fois par raison, puis rappelée toutes les 10 min avec le nombre de refus tant qu'elle dure) et
           retentée par la boucle lente ; une zone déjà déclarée est déplacée et son état remplacé (redéclaration,
           Atelier). Anciennes clés GlobalState d'avant 1.6.0 effacées une fois, pour les seules zones et nœuds encore
           dans la config (celles d'une zone ou d'un nœud retiré partent au redémarrage du serveur).
           L'état d'une zone est public (positions déclarées par les clients sous OneSync) : rien de secret dedans, et
           chaque action revérifie la distance côté serveur sans se fier à l'abonnement (server/harvest.lua).
           T-102 : le dernier état déclaré de chaque zone est gardé ; une zone changée par l'Atelier est seulement
           notée (`touch`), puis `flush` (au `info.last` d'un lot, ou par la boucle lente au-delà de
           `editor.flushGraceMs`) traite chaque zone notée une fois : déclarée si elle est nouvelle, déplacée si son
           cercle change, différence de son état envoyée par paquets de 64 clés dans le même tour (le core la regroupe
           pour chaque abonné), retirée si elle n'existe plus. Rien ne part pour une zone dont rien de visible n'a
           changé (fatigue, repos, cicatrice, charges maximales, repousse : part serveur).
    Dépendances : shared/constants.lua, config.lua, shared/zonestate.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local GlobalState, GetGameTimer = GlobalState, GetGameTimer

local bridge = VavaGathering.bridge
local catalog = VavaGathering.catalog
local zonestate = VavaGathering.zonestate
local streaming = VavaGathering.config.streaming
local LEGACY_ZONE, LEGACY_NODE = VavaGathering.LEGACY_STATE_ZONE, VavaGathering.LEGACY_STATE_NODE

local share = {}
VavaGathering.share = share

-- zones déclarées au core (zone → true) ; une zone absente n'envoie rien : elle partira entière à sa déclaration
---@type table<string, true>
local declared = {}
-- dernier état déclaré ou envoyé, et dernier cercle, par zone (différences de l'Atelier)
---@type table<string, table>
local lastState, lastArea = {}, {}
-- zones changées par l'Atelier, en attente de diffusion : zone → GetGameTimer de la première note
---@type table<string, integer>
local touched = {}
-- état entier neuf d'une zone (server/main.lua) : définition et état, ou nil si la zone n'existe plus
---@type fun(zoneId: string): table|nil, table|nil
local builder = nil
-- appelé après chaque diffusion (empreinte de la liste de la carte, server/map.lua)
---@type fun()|nil
local afterFlush = nil
-- dernier refus écrit en console par zone : un nouveau refus est écrit aussitôt ; le même refus est compté et rappelé
-- au plus une fois toutes les REMIND_MS avec son nombre (un refus durable, `full`, ne remplit pas la console)
---@type table<string, { code: string, count: integer, at: integer }>
local failures = {}
local REMIND_MS = 600000
-- module à l'arrêt : le core oublie ses zones de lui-même, plus rien n'est déclaré ni envoyé
local stopped = false

---@param zoneId string
---@param action string
---@param code any
local function failed(zoneId, action, code)
    code = tostring(code)
    local now, last = GetGameTimer(), failures[zoneId]
    if last and last.code == code then
        last.count = last.count + 1
        if now - last.at < REMIND_MS then return end
        VavaGathering.log.error("zone '%s' toujours refusée par le core (%s : %s, %d refus depuis le dernier message) ; nouvel essai au prochain passage",
            zoneId, action, code, last.count)
        last.count, last.at = 0, now
        return
    end
    failures[zoneId] = { code = code, count = 0, at = now }
    VavaGathering.log.error("zone '%s' non partagée avec les joueurs proches (%s : %s) ; nouvel essai au prochain passage", zoneId, action, code)
end

--- Cercle de la zone du core pour une zone de récolte.
---@param def vAvA.ZoneDefinition
---@return table
function share.area(def)
    return zonestate.area(def, catalog.nodesOf(def.id), streaming.radius + streaming.subscribeSlack)
end

--- Déclare une zone (ou la redéclare entière : déplacée, état remplacé). Les joueurs proches la reçoivent, eux seuls.
---@param def vAvA.ZoneDefinition
---@param state table  état entier (zonestate.build)
---@return boolean ok
---@return string|nil code
function share.declare(def, state)
    if stopped then return false, 'stopped' end
    local id, area = def.id, share.area(def)
    local ok, code, action
    if not declared[id] then
        action = 'define'
        ok, code = bridge.ZoneDefine(id, area, state)
    end
    -- déjà déclarée, ou connue du core sans l'être d'ici (un envoi refusé l'a fait oublier) : lieu et état remplacés
    if declared[id] or code == 'exists' then
        action = 'move'
        ok, code = bridge.ZoneMove(id, area)
        if ok then
            action = 'replace'
            ok, code = bridge.ZoneReplace(id, state)
        end
    end
    if ok then
        declared[id], failures[id] = true, nil
        lastState[id], lastArea[id] = state, area
        return true
    end
    declared[id], lastState[id], lastArea[id] = nil, nil, nil
    failed(id, action, code)
    return false, tostring(code)
end

---@param zoneId string
---@return boolean
function share.isDeclared(zoneId)
    return declared[zoneId] == true
end

--- Change une clé de l'état d'une zone déclarée (envoyée aux seuls abonnés en fin de tour). Zone pas encore déclarée :
--- rien ne part (elle partira entière à sa déclaration). Refus : la zone sera redéclarée entière au passage suivant.
---@param zoneId string
---@param key string
---@param value any
---@return boolean ok
function share.set(zoneId, key, value)
    if stopped or not declared[zoneId] then return false end
    local ok, code = bridge.ZoneSet(zoneId, { [key] = value })
    if ok then
        if lastState[zoneId] then lastState[zoneId][key] = value end
        return true
    end
    declared[zoneId], lastState[zoneId], lastArea[zoneId] = nil, nil, nil
    failed(zoneId, 'set', code)
    return false
end

-- Atelier (T-102) -------------------------------------------------------------------------------------------------------

--- Fonctions de la diffusion : `build(zoneId)` rend la définition et l'état entier neuf d'une zone (nil, nil si elle
--- n'existe plus) ; `after()` est appelé après chaque diffusion.
---@param build fun(zoneId: string): table|nil, table|nil
---@param after fun()|nil
function share.configure(build, after)
    builder, afterFlush = build, after
end

--- Zone changée par l'Atelier : notée, diffusée au prochain `flush`.
---@param zoneId string
function share.touch(zoneId)
    if type(zoneId) == 'string' and not touched[zoneId] then touched[zoneId] = GetGameTimer() end
end

---@param a table|nil
---@param b table
---@return boolean
local function sameArea(a, b)
    return a ~= nil and a.x == b.x and a.y == b.y and a.z == b.z and a.radius == b.radius and a.margin == b.margin
end

--- Diffuse une zone notée : déclarée (nouvelle), déplacée et sa différence envoyée (connue), ou retirée.
---@param id string
local function flushOne(id)
    local def, state = builder(id)
    if not def then
        if declared[id] then
            local ok, code = bridge.ZoneRemove(id)
            if not ok and code ~= 'unknown_zone' then failed(id, 'remove', code) end
        end
        declared[id], lastState[id], lastArea[id], failures[id] = nil, nil, nil, nil
        return
    end
    if not declared[id] then
        share.declare(def, state)
        return
    end
    local area = share.area(def)
    if not sameArea(lastArea[id], area) then
        local ok, code = bridge.ZoneMove(id, area)
        if not ok then
            declared[id], lastState[id], lastArea[id] = nil, nil, nil
            failed(id, 'move', code)
            return
        end
        lastArea[id] = area
    end
    local changes, removed = zonestate.diff(lastState[id], state)
    for _, chunk in ipairs(zonestate.chunks(changes, removed)) do
        local ok, code = bridge.ZoneSet(id, chunk.changes, #chunk.removed > 0 and chunk.removed or nil)
        if not ok then
            -- redéclarée entière au passage suivant de la boucle lente
            declared[id], lastState[id], lastArea[id] = nil, nil, nil
            failed(id, 'set', code)
            return
        end
    end
    lastState[id] = state
end

--- Diffuse les zones notées (toutes, ou celles notées depuis plus de `graceMs`) : chacune une fois, sans céder la main
--- (les différences d'un même tour partent ensemble chez chaque abonné).
---@param graceMs? integer
function share.flush(graceMs)
    if stopped or not builder then return end
    local now, any = GetGameTimer(), false
    local ids = {}
    for id, at in pairs(touched) do
        if not graceMs or now - at >= graceMs then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        touched[id] = nil
        flushOne(id)
        any = true
    end
    if any and afterFlush then afterFlush() end
end

--- Arrêt du module : plus aucune déclaration ni aucun envoi (le core oublie nos zones sans rien envoyer, et chaque
--- client oublie celles de la ressource arrêtée).
function share.stop()
    stopped = true
end

---@param key string
local function clearLegacy(key)
    if GlobalState[key] ~= nil then
        GlobalState[key] = nil -- audit: ok (clé d'avant 1.6.0 effacée une fois au démarrage, seulement si elle existe encore)
    end
end

--- Efface les anciennes clés GlobalState (avant 1.6.0) qu'un serveur resté allumé garderait encore : sans cela, elles
--- partiraient à chaque joueur qui se connecte jusqu'au prochain redémarrage du serveur. Appelé pendant le setup.
function share.clearLegacy()
    for _, def in ipairs(catalog.zones()) do clearLegacy(LEGACY_ZONE .. def.id) end
    for id in pairs(catalog.nodes()) do clearLegacy(LEGACY_NODE .. id) end
end
