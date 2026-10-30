--[[
    vava_example_items/server/main.lua
    Rôle : déclaration des sept objets d'exemple dans le registre de l'inventaire (l'Outre d'eau vient de
           vava_provisions depuis 1.3.0). La nourriture et les boissons ne
           déclarent que leurs effets (`effects`) : l'inventaire consomme une unité et vava_needs les applique, sans
           une ligne de code ici. Un objet à usage particulier fournirait `onUse` (voir docs/api.md).
           Les objets sont redéclarés à chaque annonce `core:module:ready` de l'inventaire (1.1.1) : après un
           `restart vava_inventory`, les piles gardées à part reviennent sans redémarrer ce module.
           Garde (1.2.0) : sans `set vava_env dev`, `setup` refuse et aucun objet n'est déclaré (ni au catalogue, ni
           à l'usage) ; les piles déjà dans une besace ou un grenier sont gardées à part par l'inventaire, jamais
           effacées, et reviennent quand le module tourne de nouveau en mode développement.
    Dépendances : vAvA_core (API v1), vava_inventory ≥ 1.1.0 ; vava_needs pour que manger et boire aient un effet
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local GetConvar = GetConvar

local INVENTORY = 'vava_inventory'
-- mode développement : même convar et même valeur que les autres ressources d'examples/ (shared/guard.lua)
local DEV_CONVAR, DEV_VALUE, DEV_FALLBACK = 'vava_env', 'dev', 'prod'
local DEV_REFUSAL = 'mode développement absent (convar vava_env ≠ dev) : aucun objet déclaré'

--- Mode développement, relu à chaque déclaration (démarrage et redémarrage de l'inventaire).
---@return boolean
local function devMode()
    return GetConvar(DEV_CONVAR, DEV_FALLBACK) == DEV_VALUE
end
local ITEMS_REGISTRY = 'vava_inventory:items'
local IMAGE_ROOT = ('nui://%s/web/items/'):format(RESOURCE)

---@param name string
---@return string
local function image(name)
    return IMAGE_ROOT .. name .. '.svg'
end

local ITEMS = {
    pain = {
        label = 'Miche de pain', description = 'Croûte épaisse, mie serrée.',
        width = 2, height = 1, weight = 400, stack = 10, category = 'nourriture', image = image('pain'),
        effects = { hunger = 35 },
    },
    pomme = {
        label = 'Pomme', description = 'Croquante et un peu acide.',
        width = 1, height = 1, weight = 150, stack = 20, category = 'nourriture', image = image('pomme'),
        effects = { hunger = 12, thirst = 4 },
    },
    -- l'eau est un objet du royaume : vava_provisions (T-130) ; déclarée ici, elle garderait sa forme d'exemple
    biere = {
        label = 'Chope de bière', description = 'Brassée à l\'auberge, mousse épaisse.',
        width = 1, height = 1, weight = 600, stack = 5, category = 'boisson', image = image('biere'),
        effects = { thirst = 25, hunger = 5 },
    },
    bandage = {
        label = 'Bande de lin', description = 'De quoi panser une plaie et arrêter le sang.',
        width = 1, height = 1, weight = 50, stack = 10, category = 'soin', image = image('bandage'),
        effects = { health = 20 },
    },
    epee = {
        label = 'Épée courte', description = 'Lame d\'acier forgée, fourreau de cuir.',
        width = 1, height = 4, weight = 1800, stack = 1, category = 'arme', image = image('epee'),
    },
    bourse = {
        label = 'Bourse de cuir', description = 'Une petite bourse fermée par un lacet.',
        width = 1, height = 1, weight = 100, stack = 1, category = 'divers', image = image('bourse'),
    },
    corde = {
        label = 'Rouleau de corde', description = 'Chanvre tressé, une dizaine de toises.',
        width = 2, height = 2, weight = 1200, stack = 1, category = 'outil', image = image('corde'),
    },
}

--- Déclare les objets qui ne le sont pas encore (le registre renaît vide quand l'inventaire redémarre).
---@return boolean ok
---@return string|nil err
local function declare()
    for name, definition in pairs(ITEMS) do
        if not core.registry.has(ITEMS_REGISTRY, name) then
            local ok, err = core.registry.add(ITEMS_REGISTRY, name, definition)
            if not ok then return false, err end
        end
    end
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = '0.3.0',
    dependencies = { vava_inventory = '1.1.0' },
    setup = function()
        -- objets de démonstration (une Bande de lin soigne) : rien n'est offert hors du mode développement
        if not devMode() then return false, DEV_REFUSAL end
        local ok, err = declare()
        if not ok then return false, err end
        -- inventaire redémarré : ses registres ont disparu avec lui, les objets sont redéclarés dès qu'il est prêt
        local id
        id, err = core.hooks.after('core:module:ready', function(payload)
            if payload.name ~= INVENTORY then return end
            -- set vava_env prod depuis le démarrage : l'inventaire redémarré ne retrouve pas les objets d'exemple
            if not devMode() then
                core.log.warn('objets non redéclarés : %s', DEV_REFUSAL)
                return
            end
            local redeclared, declareErr = declare()
            if not redeclared then core.log.warn('objets non redéclarés : %s', tostring(declareErr)) end
        end)
        if not id then return false, err end
        return true
    end,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
