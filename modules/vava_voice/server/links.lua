--[[
    vava_voice/server/links.lua
    Rôle : liens avec les autres modules, aucun n'est requis :
      - vava_health : à terre, portée limitée (config.downedMaxRange) jusqu'à la réanimation ou au retour au lieu de
        soins ; relu à chaque apparition (déconnecté à terre, reconnecté à terre) ;
      - vava_admin : droits du Conseil pour les zones, outil « Zones de voix » ajouté au Registre (et rajouté s'il
        redémarre), actions inscrites à son journal.
    Appels inter-ressources isolés : un module absent ou en erreur ne fait qu'ôter le lien.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/presence.lua
]]

local pcall, tostring, ipairs = pcall, tostring, ipairs
local pack, unpack = table.pack, table.unpack
local GetResourceState = GetResourceState

local presence = VavaVoice.presence
local cfg = VavaVoice.config
local ADMIN = VavaVoice.ADMIN
local HEALTH = VavaVoice.HEALTH
local DOWNED = VavaVoice.LIMIT_DOWNED

local links = {}
VavaVoice.links = links

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie ok (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaVoice.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

--- Droit du Conseil (vava_admin) : sans lui, personne n'a de droit.
---@param src integer
---@param permission string
---@return boolean
function links.can(src, permission)
    local called, allowed = call(ADMIN.RESOURCE, 'can', src, permission)
    return called and allowed == true
end

--- Inscrit une action au journal du Registre ; sans vava_admin, la console du serveur la garde.
---@param src integer
---@param label string
---@param details table
function links.record(src, label, details)
    local called, ok, err = call(ADMIN.RESOURCE, 'log', src, label, details)
    if not called or ok ~= true then
        VavaVoice.log.info('%s (joueur %d) : %s%s', label, src, tostring(details.zone), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Ajoute l'outil « Zones de voix » au Registre, s'il est là.
local function addTool()
    local registry = VavaVoice.core.registry
    if not registry.exists(ADMIN.REGISTRY) or registry.has(ADMIN.REGISTRY, ADMIN.TOOL) then return end
    local ok, err = registry.add(ADMIN.REGISTRY, ADMIN.TOOL, {
        label = cfg.zones.tool.label, hint = cfg.zones.tool.hint, permission = cfg.zones.permission,
    })
    if not ok then VavaVoice.log.warn('outil du Registre non ajouté : %s', tostring(err)) end
end

--- À terre ou non : limite de portée posée ou levée.
---@param src integer
function links.syncHealth(src)
    local called, downed = call(HEALTH.RESOURCE, 'isDowned', src)
    if called and downed == true then
        presence.limit(src, DOWNED, cfg.downedMaxRange)
    else
        presence.release(src, DOWNED)
    end
end

--- Branche les hooks. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function links.start()
    local hooks = VavaVoice.core.hooks
    local release = function(payload) presence.release(payload.source, DOWNED) end
    for _, def in ipairs({
        { HEALTH.DOWNED, function(payload) presence.limit(payload.source, DOWNED, cfg.downedMaxRange) end },
        { HEALTH.REVIVED, release },
        { HEALTH.RESPAWNED, release },
        { ADMIN.READY, addTool },
    }) do
        local id, err = hooks.after(def[1], def[2])
        if not id then return false, err end
    end
    addTool()
    return true
end
