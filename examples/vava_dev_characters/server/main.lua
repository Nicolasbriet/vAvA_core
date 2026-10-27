--[[
    vava_dev_characters/server/main.lua
    Rôle : outils de test côté serveur :
      - /respawn : le joueur exprime l'intention, le serveur décide de la position (dernière position connue) ;
      - /objet   : donne un objet au personnage actif via l'API de l'inventaire ;
      - /besoins : lit ou fixe la faim et la soif du personnage actif via l'API de vava_needs ;
      - /vie     : lit ou fixe la vie, /aterre met à terre, via l'API de vava_health.
    Dépendances : vAvA_core (API v1, core ≥ 0.4.0), vava_inventory, vava_needs, vava_health, config.lua
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaDevCharacters.config

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local RPC_RESPAWN = RESOURCE .. ':respawn'
local RPC_GIVE = RESOURCE .. ':give'
local RPC_NEEDS = RESOURCE .. ':needs'
local RPC_HEALTH = RESOURCE .. ':health'
local RPC_DOWN = RESOURCE .. ':down'
local NEED_VALUE = { type = 'number', min = 0, max = 100, optional = true }
local PERCENT = 100

--- Sans valeur : lecture de la vie (en pour cent) ; sinon elle est fixée.
local function health(source, percent)
    if percent ~= nil then
        local ok, code = exports.vava_health:setHealth(source, percent / PERCENT)
        if not ok then return false, code end
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
    return exports.vava_needs:set(source, { hunger = hunger, thirst = thirst })
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = { vava_inventory = '1.1.0', vava_needs = '1.1.0', vava_health = '1.0.0' },
    setup = function()
        local ok, err = core.rpc.register(RPC_RESPAWN, { args = {}, rateLimit = cfg.respawnRateLimit }, function(source)
            return core.characters.spawn(source)
        end)
        if not ok then return false, err end
        ok, err = core.rpc.register(RPC_NEEDS, { args = { NEED_VALUE, NEED_VALUE }, rateLimit = cfg.needsRateLimit }, needs)
        if not ok then return false, err end
        ok, err = core.rpc.register(RPC_HEALTH, { args = { NEED_VALUE }, rateLimit = cfg.healthRateLimit }, health)
        if not ok then return false, err end
        ok, err = core.rpc.register(RPC_DOWN, { args = {}, rateLimit = cfg.healthRateLimit }, function(source)
            return exports.vava_health:down(source, 'test')
        end)
        if not ok then return false, err end
        return core.rpc.register(RPC_GIVE, {
            args = {
                { type = 'string', min = 1, max = 64, pattern = '^[%w_%-%.:]+$' },
                { type = 'integer', min = 1, max = cfg.maxGiveQuantity, optional = true },
            },
            rateLimit = cfg.giveRateLimit,
        }, function(source, item, quantity)
            return exports.vava_inventory:add(source, item, quantity or 1)
        end)
    end,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
