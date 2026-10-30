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
    Dépendances : shared/constants.lua, config.lua, shared/zonestate.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
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
        return true
    end
    declared[id] = nil
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
    if ok then return true end
    declared[zoneId] = nil
    failed(zoneId, 'set', code)
    return false
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
