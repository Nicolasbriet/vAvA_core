--[[
    vava_combat/server/main.lua
    Rôle : déclaration du module auprès du core : commande du Conseil et touches au registre, catalogue des armes et des
           techniques contrôlé (refus avec la raison), objets, recettes et champ déclarés, garde du statebag du bouclier
           branchée et peds vidés, RPC des techniques `vava_combat:use` et de la garde `vava_combat:lower` (schémas
           bornés, limites de débit), modificateurs de la défense déclarés (et redéclarés au retour de vava_health),
           hooks (retour de l'inventaire, de l'artisanat, des compétences et de la santé ; apparition, déchargement et
           départ ; pile du bouclier qui quitte la besace ; prise en main : dégainer et rengainer ; mise à terre : coup
           annulé ; coup de la chaîne : suites d'une défense), boucliers et armes en main repris pour les personnages
           déjà en jeu. Aucune table SQL. À l'arrêt de la ressource, les statebags de
           bouclier sont vidés et les coups en cours annulés.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring, type = ipairs, tostring, type
local AddEventHandler, RegisterCommand = AddEventHandler, RegisterCommand

local core = VavaCombat.core
if not core then return end

local bridge = VavaCombat.bridge
local catalog = VavaCombat.catalog
local pedState = VavaCombat.pedState
local shields = VavaCombat.shields
local wear = VavaCombat.wear
local hands = VavaCombat.hands
local reactions = VavaCombat.reactions
local swings = VavaCombat.swings
local defense = VavaCombat.defense
local commands = VavaCombat.commands
local cfg = VavaCombat.config
local RPC = VavaCombat.RPC
local TECHNIQUE_PATTERN, TECHNIQUE_MAX, MAX_PLAYER = VavaCombat.TECHNIQUE_PATTERN, VavaCombat.TECHNIQUE_MAX,
    VavaCombat.MAX_PLAYER

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
    elseif payload.name == bridge.HEALTH and VavaCombat.ready then
        -- le registre des modificateurs disparaît avec vava_health : redéclarés à son retour
        core.log.info('vava_health de retour : %d modificateur(s) de la défense redéclaré(s)', defense.declare())
    end
end

---@param payload { source: integer }
local function onSpawned(payload)
    shields.restore(payload.source)
    hands.learn(payload.source)
end

--- Personnage déchargé ou joueur parti : statebag vidé, coup annulé, mémoire oubliée (champ gardé).
---@param payload { source: integer }
local function forget(payload)
    local src = payload.source
    shields.release(src)
    wear.forget(src)
    swings.forget(src)
    hands.forget(src)
    reactions.forget(src)
    defense.forget(src)
end

--- Mise à terre : coup en cours annulé, chancellement oublié.
---@param payload { source: integer }
local function onDowned(payload)
    if type(payload) ~= 'table' or type(payload.source) ~= 'number' then return end
    swings.onDowned(payload.source)
    reactions.onDowned(payload.source)
    defense.onDowned(payload.source)
end

local function setup()
    -- T-132 : un config.lua d'avant 1.1.0 (gardé par une mise à jour) remplace la table de config_client.lua ; depuis
    -- 1.2.0, le contrôle du catalogue le refuse (weaponClasses absent) avec la marche à suivre
    if VavaCombat.config.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.1.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
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
    local hooked, holdErr = bridge.OnHold(hands.onHold)
    if not hooked then return false, 'vava_inventory:hold : ' .. tostring(holdErr) end
    local downedHooked, downedErr = bridge.OnDowned(onDowned)
    if not downedHooked then return false, 'vava_health:downed : ' .. tostring(downedErr) end
    local hitHooked, hitErr = bridge.OnHitAfter(defense.onHitAfter)
    if not hitHooked then return false, 'vava_health:hit : ' .. tostring(hitErr) end

    local registered, rpcErr = bridge.RegisterRpc(RPC.USE, {
        args = {
            { type = 'string', min = 1, max = TECHNIQUE_MAX, pattern = TECHNIQUE_PATTERN },  -- technique
            { type = 'integer', min = 0, max = MAX_PLAYER },                                -- cible verrouillée (0 : aucune)
        },
        rateLimit = cfg.rateLimits.use,
    }, swings.use)
    if not registered then return false, RPC.USE .. ' : ' .. tostring(rpcErr) end
    registered, rpcErr = bridge.RegisterRpc(RPC.LOWER, { args = {}, rateLimit = cfg.rateLimits.lower }, defense.lowerRpc)
    if not registered then return false, RPC.LOWER .. ' : ' .. tostring(rpcErr) end

    local started, startErr = pedState.start()
    if not started then return false, 'statebag du bouclier : ' .. tostring(startErr) end
    RegisterCommand(cfg.admin.command, commands.handle, false)
    VavaCombat.ready = true
    shields.restoreAll()
    for _, src in ipairs(bridge.ActivePlayers()) do hands.learn(src) end
    local modifiers = defense.declare()
    local techniqueCount, styleCount = catalog.counts()
    core.log.info('prêt : %d objets et %d recettes déclarés, %d armes au catalogue, %d techniques, %d style(s), '
        .. '%d modificateur(s) de la défense', items, recipes, #catalog.list(), techniqueCount, styleCount, modifiers)
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

-- arrêt du module : aucun ped ne garde un bouclier que plus personne n'accroche, aucun coup en cours ne frappe
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaCombat.resource then return end
    VavaCombat.ready = false
    swings.stop()
    hands.stop()
    reactions.stop()
    defense.stop()
    pedState.stop()
    shields.stop()
end)
