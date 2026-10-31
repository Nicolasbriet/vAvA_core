--[[
    vava_combat/server/shields.lua
    Rôle : le bouclier accroché. « Utiliser » un bouclier de la besace (onUse, appelé par l'inventaire qui a déjà vérifié
           la possession, la besace et sa limite `use`) l'accroche ou le décroche ; rien ne bouge dans l'inventaire, le
           bouclier reste dans la besace (place et poids). Le serveur publie { id, item } sur le statebag du ped
           (server/pedstate.lua) et retient la pile dans un champ privé du personnage (retrouvée à la reconnexion). Il
           décroche dès que la pile quitte la besace (hooks `move`, `drop`, `remove` de l'inventaire), et un relevé lent
           (seulement tant qu'un bouclier est accroché) rattrape un hook manqué ou un redémarrage de l'inventaire.
           Aucune de ces fonctions ne cède la main pendant l'utilisation.
    Dépendances : shared/constants.lua, config.lua, shared/shield.lua, shared/weapons.lua, server/core.lua,
                  bridge/server.lua, server/catalog.lua, server/pedstate.lua
]]

local type, pairs, ipairs, next = type, pairs, ipairs, next
local tointeger = math.tointeger
local format = string.format
local CreateThread, Wait = CreateThread, Wait

local bridge = VavaCombat.bridge
local catalog = VavaCombat.catalog
local pedState = VavaCombat.pedState
local shield = VavaCombat.shield
local weapons = VavaCombat.weapons
local cfg = VavaCombat.config
local HOOK = VavaCombat.HOOKS.SHIELD_HANG
local SHIELD = VavaCombat.SHIELD_CATEGORY

local shields = {}
VavaCombat.shields = shields

---@class vAvA.HungShield
---@field instanceId integer
---@field item string
---@field characterId integer
---@field container integer|nil  besace du porteur (relue au besoin)
---@field misses integer         relevés manquants d'affilée

---@type table<integer, vAvA.HungShield>  source → bouclier accroché
local hung = {}
-- numéro de pile → source du porteur
local byInstance = {}
-- besace (numéro de conteneur) → source du porteur : un retrait d'objet ne regarde que ce porteur
local byContainer = {}
-- source → instant du dernier geste d'accroche
local lastToggle = {}
local verifying = false

---@param list table[]
---@param instanceId integer
---@return table|nil pile
local function find(list, instanceId)
    for _, pile in ipairs(list) do
        if pile.id == instanceId then return pile end
    end
    return nil
end

---@param src integer
---@param entry vAvA.HungShield
---@param hang boolean
---@param reason string
local function announce(src, entry, hang, reason)
    bridge.RunAfter(HOOK, {
        source = src, characterId = entry.characterId, instanceId = entry.instanceId, item = entry.item, hang = hang,
        reason = reason,
    })
end

--- Retire un porteur des index (seulement ce qui pointe encore vers lui).
---@param src integer
---@param entry vAvA.HungShield
local function unindex(src, entry)
    if byInstance[entry.instanceId] == src then byInstance[entry.instanceId] = nil end
    if entry.container and byContainer[entry.container] == src then byContainer[entry.container] = nil end
end

--- Besace du porteur, relue si elle manquait (inventaire muet à l'accroche), et indexée.
---@param src integer
---@param entry vAvA.HungShield
---@return integer|nil
local function containerOf(src, entry)
    if not entry.container then
        entry.container = bridge.ContainerOf(src)
        if entry.container then byContainer[entry.container] = src end
    end
    return entry.container
end

--- Décroche le bouclier d'un joueur : statebag vidé, champ effacé (sauf `keepField`), hook `after`.
---@param src integer
---@param reason string  use | gone
---@param keepField? boolean
local function unhang(src, reason, keepField)
    local entry = hung[src]
    if not entry then return end
    hung[src] = nil
    unindex(src, entry)
    pedState.set(src, nil)
    if not keepField then bridge.SetShieldField(entry.characterId, nil) end
    announce(src, entry, false, reason)
end

--- Un relevé de possession : une pile absente `missesToDrop` fois d'affilée est décrochée ; inventaire muet : sauté.
function shields.verify()
    for src, entry in pairs(hung) do
        if bridge.ActiveCharacterId(src) ~= entry.characterId then
            -- personnage parti sans déchargement vu par ce module : oublié, champ gardé
            shields.release(src)
        else
            local list = bridge.Items(src, entry.item)
            if list then
                if find(list, entry.instanceId) then
                    entry.misses = 0
                else
                    entry.misses = entry.misses + 1
                    if entry.misses >= cfg.shield.missesToDrop then unhang(src, 'gone') end
                end
            end
        end
    end
end

--- Relevé lent justifié : un appel d'export par bouclier accroché toutes les verifyMs ; s'arrête quand plus aucun
--- bouclier n'est accroché.
local function startVerify()
    if verifying then return end
    verifying = true
    CreateThread(function()
        while next(hung) ~= nil do
            Wait(cfg.shield.verifyMs)
            shields.verify()
        end
        verifying = false
    end)
end

--- Accroche un bouclier : mémoire, statebag, champ, hook `after`.
---@param src integer
---@param characterId integer
---@param instanceId integer
---@param item string
---@param reason string  use | restored
local function hang(src, characterId, instanceId, item, reason)
    -- une même pile ne s'accroche qu'à un porteur : un ancien porteur encore en mémoire (hook manqué) est décroché
    local previous = byInstance[instanceId]
    if previous and previous ~= src then unhang(previous, 'gone') end
    local entry = { instanceId = instanceId, item = item, characterId = characterId,
        container = bridge.ContainerOf(src), misses = 0 }
    hung[src] = entry
    byInstance[instanceId] = src
    if entry.container then byContainer[entry.container] = src end
    pedState.set(src, shield.value(instanceId, item))
    bridge.SetShieldField(characterId, instanceId)
    announce(src, entry, true, reason)
    startVerify()
end

--- « Utiliser » un bouclier (onUse de l'objet). Rend toujours `false` (aucune unité consommée), et le message à montrer.
---@param src integer
---@param instance table  pile utilisée { id, item, … }
---@return boolean consume
---@return string|nil message
function shields.onUse(src, instance)
    if type(instance) ~= 'table' then return false end
    local characterId = bridge.ActiveCharacterId(src)
    if not characterId then return false end
    local messages = cfg.messages
    if bridge.IsDowned(src) then return false, messages.shieldDowned end
    local def = catalog.weapon(instance.item)
    local id = type(instance.id) == 'number' and tointeger(instance.id) or nil
    if not def or def.category ~= SHIELD or not id then return false end
    local now = bridge.Timer()
    local last = lastToggle[src]
    if last and now - last < cfg.shield.toggleMs then return false, messages.tooSoon end
    lastToggle[src] = now

    local current = hung[src]
    if current and current.instanceId == id then
        unhang(src, 'use')
        return false, format(messages.shieldUnhung, def.label)
    end
    local allowed, reason = bridge.RunBefore(HOOK, { source = src, characterId = characterId, instanceId = id, item = instance.item })
    if not allowed then return false, type(reason) == 'string' and reason or nil end
    -- un autre bouclier accroché est remplacé (son champ est réécrit aussitôt)
    if current then unhang(src, 'use', true) end
    hang(src, characterId, id, instance.item, 'use')
    return false, format(messages.shieldHung, def.label)
end

-- Hooks de l'inventaire (phase after) -------------------------------------------------------------------------------

--- Pile déplacée : le bouclier accroché qui quitte la besace de son porteur est décroché aussitôt.
---@param payload { instanceId: integer, to: integer }
function shields.onMove(payload)
    if type(payload) ~= 'table' then return end
    local src = byInstance[payload.instanceId]
    local entry = src and hung[src]
    if not entry then return end
    local container = containerOf(src, entry)
    -- besace inconnue (inventaire muet) : le relevé lent tranchera
    if container and payload.to ~= container then unhang(src, 'gone') end
end

--- Pile jetée au sol : décrochée aussitôt.
---@param payload { instanceId: integer }
function shields.onDrop(payload)
    if type(payload) ~= 'table' then return end
    local src = byInstance[payload.instanceId]
    if src then unhang(src, 'gone') end
end

--- Retrait par un module (échange, recette, retrait) dans la besace d'un porteur, par numéro de pile ou par objet :
--- possession relue, décroché si la pile n'y est plus. Seul le porteur de cette besace est regardé (index).
---@param payload { container: integer, removals: table[] }
function shields.onRemove(payload)
    if type(payload) ~= 'table' or type(payload.removals) ~= 'table' then return end
    local src = byContainer[payload.container]
    local entry = src and hung[src]
    if not entry then return end
    for _, removal in ipairs(payload.removals) do
        if type(removal) == 'table' and (removal.instanceId == entry.instanceId or removal.item == entry.item) then
            local list = bridge.Items(src, entry.item)
            if list and not find(list, entry.instanceId) then unhang(src, 'gone') end
            return
        end
    end
end

-- Reprise et oubli --------------------------------------------------------------------------------------------------

--- Reprend le bouclier retenu d'un personnage en jeu : toujours dans la besace et toujours un bouclier → republié ;
--- sinon champ effacé. Inventaire muet : rien (le champ est gardé).
---@param src integer
function shields.restore(src)
    if hung[src] then return end
    local characterId = bridge.ActiveCharacterId(src)
    if not characterId then return end
    local id = bridge.ShieldField(characterId)
    if not id then return end
    for item in pairs(cfg.shields) do
        local list = bridge.Items(src, item)
        if not list then return end
        if find(list, id) then
            hang(src, characterId, id, item, 'restored')
            return
        end
    end
    bridge.SetShieldField(characterId, nil)
end

--- Reprend les boucliers de tous les personnages en jeu (démarrage du module, retour de l'inventaire).
function shields.restoreAll()
    for _, src in ipairs(bridge.ActivePlayers()) do shields.restore(src) end
end

--- Déchargement, départ : statebag vidé, mémoire oubliée ; le champ est gardé (retrouvé à la reconnexion).
---@param src integer
function shields.release(src)
    local entry = hung[src]
    if entry then
        hung[src] = nil
        unindex(src, entry)
        pedState.set(src, nil)
    end
    pedState.forget(src)
    lastToggle[src] = nil
end

-- Lecture -------------------------------------------------------------------------------------------------------------

--- Bouclier accroché d'un joueur (mémoire du module), ou nil.
---@param src integer
---@return vAvA.HungShield|nil
function shields.hungOf(src)
    return hung[src]
end

--- Vue du bouclier accroché pour l'export `shield(src)` : solidité lue sur la pile, position d'après la main tenue
--- (lue par le serveur), `ready` au bras. Nil si rien n'est accroché, si l'inventaire ne répond pas (rien n'est
--- affirmé sans la pile), ou si la pile n'est plus dans la besace : elle est alors décrochée aussitôt.
---@param src integer
---@return table|nil
function shields.view(src)
    local entry = hung[src]
    if not entry then return nil end
    local def = catalog.weapon(entry.item)
    if not def then return nil end
    local list = bridge.Items(src, entry.item)
    if not list then return nil end
    local pile = find(list, entry.instanceId)
    if not pile then
        unhang(src, 'gone')
        return nil
    end
    local d = weapons.durabilityOf(pile.metadata, def)
    local held = bridge.Held(src)
    local position = shield.position(held and held.item or nil, cfg.weaponClasses, cfg.shield.armWith,
        cfg.shield.armWithEmptyHand)
    return {
        instanceId = entry.instanceId, item = entry.item, block = def.block, durability = d.current,
        maxDurability = d.max, dull = d.dull, position = position, ready = position == shield.ARM,
    }
end

--- Arrêt du module : tout est oublié (les statebags sont vidés par pedState.stop).
function shields.stop()
    hung, byInstance, byContainer, lastToggle = {}, {}, {}, {}
end
