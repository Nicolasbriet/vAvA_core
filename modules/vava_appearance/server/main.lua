--[[
    vava_appearance/server/main.lua
    Rôle : déclaration du champ d'apparence (visible du seul joueur concerné : le jeu synchronise lui-même l'aspect
           du ped pour les autres) et création d'un personnage avec son apparence, en une seule intention validée.
    Dépendances : vAvA_core (API v1, core ≥ 0.3.0), shared/, server/schema.lua
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaAppearance.config

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local RPC_CREATE = RESOURCE .. ':create'
-- le core valide précisément les noms et le sexe ; ici, seules les bornes réseau
local NAME_ARG = { type = 'string', min = 1, max = 96 }
local SEX_ARG = { type = 'string', min = 1, max = 8 }

---@param source integer
---@param firstName string
---@param lastName string
---@param sex string
---@param appearance vAvA.Appearance
local function createWithAppearance(source, firstName, lastName, sex, appearance)
    return core.characters.create(source,
        { firstName = firstName, lastName = lastName, sex = sex },
        { [VavaAppearance.FIELD] = VavaAppearance.normalize(appearance) })
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = function()
        local ok, err = core.characters.defineField(VavaAppearance.FIELD, {
            schema = VavaAppearance.SCHEMA,
            visibility = 'owner',
        })
        if not ok then return false, err end
        return core.rpc.register(RPC_CREATE, {
            args = { NAME_ARG, NAME_ARG, SEX_ARG, VavaAppearance.SCHEMA },
            rateLimit = cfg.createRateLimit,
        }, createWithAppearance)
    end,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
