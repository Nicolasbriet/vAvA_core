--[[
    vava_dev_characters/server/main.lua
    Rôle : outils de test côté serveur, offerts seulement en mode développement et à qui y a droit :
      - garde      : `setup` refuse sans `set vava_env dev` (aucun RPC, rien d'offert) ; chaque RPC revérifie
                     l'accès du joueur (droit vava_admin `staff` ou ACE `vava.dev`, config `access`) ;
      - /perso     : le client demande l'accès (vava_dev_characters:access) avant d'appeler les RPC du core ;
      - /respawn   : le joueur exprime l'intention, le serveur décide de la position (dernière position connue) ;
      - /objet     : donne un objet au personnage actif via l'API de l'inventaire ;
      - /besoins   : lit ou fixe la faim et la soif du personnage actif via l'API de vava_needs ;
      - /vie       : lit ou fixe la vie, /aterre met à terre, via l'API de vava_health.
      Chaque changement (don, vie, mise à terre, besoins, réapparition) est inscrit au journal du Registre
      (vava_admin:log), ou à la console du serveur sans lui.
    Dépendances : vAvA_core (API v1, core ≥ 0.4.0), vava_inventory, vava_needs, vava_health, config.lua,
                  shared/guard.lua ; facultatif : vava_admin (droit et journal)
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaDevCharacters.config
local guard = VavaDevCharacters.guard

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local pcall, pairs, ipairs, tostring = pcall, pairs, ipairs, tostring
local concat, sort = table.concat, table.sort
local GetConvar, GetResourceState, IsPlayerAceAllowed = GetConvar, GetResourceState, IsPlayerAceAllowed

local ADMIN = 'vava_admin'
local RPC_ACCESS = RESOURCE .. ':access'
local RPC_RESPAWN = RESOURCE .. ':respawn'
local RPC_GIVE = RESOURCE .. ':give'
local RPC_NEEDS = RESOURCE .. ':needs'
local RPC_HEALTH = RESOURCE .. ':health'
local RPC_DOWN = RESOURCE .. ':down'
local NOT_ALLOWED = 'not_allowed'
local NEED_VALUE = { type = 'number', min = 0, max = 100, optional = true }
local PERCENT = 100

-- Accès et journal ------------------------------------------------------------------------------------------------

--- Mode développement relu à chaque appel, puis droit vava_admin (appel isolé) ou ACE : rien d'autre n'ouvre les outils.
---@param source integer
---@return boolean
local function allowed(source)
    local adminStarted = GetResourceState(ADMIN) == 'started'
    local adminCalled, adminCan = false, nil
    if adminStarted then
        adminCalled, adminCan = pcall(function() return exports[ADMIN]:can(source, cfg.access.permission) end)
    end
    return guard.allowed({
        devMode = guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)),
        adminStarted = adminStarted,
        adminCalled = adminCalled,
        adminCan = adminCan,
        ace = IsPlayerAceAllowed(source, cfg.access.ace) == true,
    })
end

--- Journal du Registre (appel isolé) ; refusé (Registre absent, joueur qui n'a que l'ACE) : console du serveur.
---@param source integer
---@param label string
---@param details table  { clé = texte ou nombre }, 8 au plus
local function journal(source, label, details)
    local called, ok, err = false, nil, nil
    if GetResourceState(ADMIN) == 'started' then
        called, ok, err = pcall(function() return exports[ADMIN]:log(source, label, details) end)
    end
    if called and ok == true then return end
    local keys = {}
    for key in pairs(details) do keys[#keys + 1] = key end
    sort(keys)
    local parts = {}
    for i, key in ipairs(keys) do parts[i] = key .. ' : ' .. tostring(details[key]) end
    core.log.info('%s (joueur %d) — %s%s', label, source, concat(parts, ' ; '),
        called and (' (journal du Registre : ' .. tostring(err or ok) .. ')') or '')
end

--- Enveloppe un handler : refus `not_allowed` sans droit, sinon le handler décide.
---@param handler fun(source: integer, ...): ...
---@return fun(source: integer, ...): ...
local function guarded(handler)
    return function(source, ...)
        if not allowed(source) then return false, NOT_ALLOWED end
        return handler(source, ...)
    end
end

-- Outils ----------------------------------------------------------------------------------------------------------

--- Sans valeur : lecture de la vie (en pour cent) ; sinon elle est fixée.
local function health(source, percent)
    if percent ~= nil then
        local ok, code = exports.vava_health:setHealth(source, percent / PERCENT)
        if not ok then return false, code end
        journal(source, cfg.journal.health, { vie = percent })
    end
    local state, code = exports.vava_health:get(source)
    if not state then return false, code end
    return true, { health = state.health * PERCENT, downed = state.downed }
end

--- Sans valeur : lecture ; sinon les valeurs données sont fixées (l'autre besoin est inchangé).
local function needs(source, hunger, thirst)
    if hunger == nil and thirst == nil then
        local values, code = exports.vava_needs:get(source)
        if not values then return false, code end
        return true, values
    end
    local ok, result = exports.vava_needs:set(source, { hunger = hunger, thirst = thirst })
    if ok then journal(source, cfg.journal.needs, { faim = hunger or '-', soif = thirst or '-' }) end
    return ok, result
end

local function down(source)
    local ok, code = exports.vava_health:down(source, 'test')
    if ok then journal(source, cfg.journal.down, { cause = 'test' }) end
    return ok, code
end

local function give(source, item, quantity)
    local count = quantity or 1
    local ok, result = exports.vava_inventory:add(source, item, count)
    if ok then journal(source, cfg.journal.give, { objet = item, quantite = count }) end
    return ok, result
end

local function respawn(source)
    local ok, code = core.characters.spawn(source)
    if ok then journal(source, cfg.journal.respawn, { lieu = 'dernière position connue' }) end
    return ok, code
end

-- Module ----------------------------------------------------------------------------------------------------------

local function setup()
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return false, guard.REFUSAL end
    local ok, err = core.rpc.register(RPC_ACCESS, { args = {}, rateLimit = cfg.accessRateLimit }, guarded(function()
        return true
    end))
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC_RESPAWN, { args = {}, rateLimit = cfg.respawnRateLimit }, guarded(respawn))
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC_NEEDS, { args = { NEED_VALUE, NEED_VALUE }, rateLimit = cfg.needsRateLimit },
        guarded(needs))
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC_HEALTH, { args = { NEED_VALUE }, rateLimit = cfg.healthRateLimit }, guarded(health))
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC_DOWN, { args = {}, rateLimit = cfg.healthRateLimit }, guarded(down))
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC_GIVE, {
        args = {
            { type = 'string', min = 1, max = 64, pattern = '^[%w_%-%.:]+$' },
            { type = 'integer', min = 1, max = cfg.maxGiveQuantity, optional = true },
        },
        rateLimit = cfg.giveRateLimit,
    }, guarded(give))
    if not ok then return false, err end
    core.log.warn('mode développement : /objet, /vie, /aterre, /besoins, /respawn et /perso ouverts au droit « %s »'
        .. ' et à l\'ACE « %s » — à ne jamais laisser sur un serveur ouvert au public',
        cfg.access.permission, cfg.access.ace)
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = { vava_inventory = '1.1.0', vava_needs = '1.1.0', vava_health = '1.0.0' },
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
