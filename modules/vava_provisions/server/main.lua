--[[
    vava_provisions/server/main.lua
    Rôle : déclaration du module auprès du core : touche et commande au registre, config vérifiée (rules.validateConfig :
           refus avec le chemin fautif), objets déclarés s'ils manquent, recette de l'outre à l'artisanat, points d'eau
           (une zone du core par point), intention du client (RPC à schéma strict et débit limité), hooks (outre bue,
           retour de l'inventaire, de l'artisanat et des compétences, joueurs déchargés ou partis), commande du
           Conseil. Aucune boucle serveur, aucune requête SQL.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring

local core = VavaProvisions.core
if not core then return end

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local items = VavaProvisions.items
local points = VavaProvisions.points
local draw = VavaProvisions.draw
local containers = VavaProvisions.containers
local admin = VavaProvisions.admin
local cfg = VavaProvisions.config
local RPC = VavaProvisions.RPC

-- identifiant du point d'eau désigné par le client (le seul argument du RPC)
local POINT = { type = 'string', min = 1, max = VavaProvisions.ID_MAX, pattern = VavaProvisions.ID_PATTERN }

--- Joueur déchargé ou parti : délais et traitements oubliés.
---@param payload { source: integer }
local function forget(payload)
    draw.forget(payload.source)
    admin.forget(payload.source)
end

--- Annonce d'un module : l'inventaire a perdu nos objets, l'artisanat ou les compétences notre recette.
---@param payload { name: string }
local function onModuleReady(payload)
    if payload.name == bridge.INVENTORY then
        items.onInventoryReady()
    elseif payload.name == bridge.CRAFTING or payload.name == bridge.SKILLS then
        items.declareRecipe()
    end
end

local function setup()
    local declared, declareErr = VavaProvisions.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local valid, code, path = rules.validateConfig(cfg)
    if not valid then return false, 'config : ' .. tostring(path) .. ' : ' .. tostring(code) end

    items.declare()
    items.declareRecipe()
    points.loadConfig()

    local ok, err = core.rpc.register(RPC.DRAW, { args = { POINT }, rateLimit = cfg.rateLimits.draw }, draw.handle)
    if not ok then return false, RPC.DRAW .. ' : ' .. tostring(err) end

    for _, def in ipairs({
        { 'vava_inventory:use', containers.onUse },
        { 'core:module:ready', onModuleReady },
        { 'core:character:unloading', forget },
        { 'core:player:dropped', forget },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, def[1] .. ' : ' .. tostring(hookErr) end
    end

    admin.start()
    VavaProvisions.ready = true
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaProvisions.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
