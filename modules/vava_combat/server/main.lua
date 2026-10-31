--[[
    vava_combat/server/main.lua
    Rôle : déclaration du module auprès du core : commande du Conseil au registre, catalogue contrôlé (refus avec la
           raison), objets, recettes et champ déclarés, garde du statebag du bouclier branchée et peds vidés, hooks
           (retour de l'inventaire, de l'artisanat et des compétences ; apparition, déchargement et départ ; pile du
           bouclier qui quitte la besace), boucliers repris pour les personnages déjà en jeu. Aucun RPC (décision 14 de
           la spec T-111), aucune table SQL. À l'arrêt de la ressource, les statebags de bouclier sont vidés.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring
local AddEventHandler, RegisterCommand = AddEventHandler, RegisterCommand

local core = VavaCombat.core
if not core then return end

local bridge = VavaCombat.bridge
local catalog = VavaCombat.catalog
local pedState = VavaCombat.pedState
local shields = VavaCombat.shields
local wear = VavaCombat.wear
local commands = VavaCombat.commands
local cfg = VavaCombat.config

--- Annonce d'un module : l'inventaire a perdu nos objets (puis les boucliers sont repris), l'artisanat nos recettes,
--- les compétences nos recettes de compétence.
---@param payload { name: string }
local function onModuleReady(payload)
    if payload.name == bridge.INVENTORY then
        catalog.onInventoryReady()
        shields.restoreAll()
    elseif payload.name == bridge.CRAFTING then
        catalog.onCraftingReady()
    elseif payload.name == bridge.SKILLS then
        catalog.onSkillsReady()
    end
end

---@param payload { source: integer }
local function onSpawned(payload)
    shields.restore(payload.source)
end

--- Personnage déchargé ou joueur parti : statebag vidé, mémoire oubliée (champ gardé).
---@param payload { source: integer }
local function forget(payload)
    shields.release(payload.source)
    wear.forget(payload.source)
end

local function setup()
    local declared, declareErr = commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, items, recipes = catalog.setup()
    if not ok then return false, items end

    for _, def in ipairs({
        { 'core:module:ready', onModuleReady },
        { 'core:character:spawned', onSpawned },
        { 'core:character:unloading', forget },
        { 'core:player:dropped', forget },
        { 'vava_inventory:move', shields.onMove },
        { 'vava_inventory:drop', shields.onDrop },
        { 'vava_inventory:remove', shields.onRemove },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, def[1] .. ' : ' .. tostring(hookErr) end
    end

    local started, startErr = pedState.start()
    if not started then return false, 'statebag du bouclier : ' .. tostring(startErr) end
    RegisterCommand(cfg.admin.command, commands.handle, false)
    VavaCombat.ready = true
    shields.restoreAll()
    core.log.info('prêt : %d objets et %d recettes déclarés, %d armes au catalogue', items, recipes, #catalog.list())
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaCombat.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end

-- arrêt du module : aucun ped ne garde un bouclier que plus personne n'accroche
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaCombat.resource then return end
    VavaCombat.ready = false
    pedState.stop()
    shields.stop()
end)
