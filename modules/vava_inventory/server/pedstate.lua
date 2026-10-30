--[[
    vava_inventory/server/pedstate.lua
    Rôle : publication de l'objet tenu en main sur le statebag du ped du porteur (1.7.0), et garde de ce statebag.
      - Valeur courte { id, item } (ou rien), sous la clé VavaInventory.HELD_STATE, répliquée : OneSync ne l'envoie
        qu'aux joueurs qui ont ce ped à portée, et la renvoie à chacun quand le ped apparaît chez lui.
      - Un statebag d'entité meurt avec elle : un nouveau ped (réapparition, changement de modèle à l'apparition d'un
        personnage) n'a plus rien. Un contrôle lent compare le ped de chaque porteur à celui où la main est écrite, la
        réécrit sur le nouveau (ou sur un statebag qui l'aurait perdue) ; il ne tourne que tant que quelqu'un tient
        quelque chose.
      - Le ped d'un joueur est possédé par son client, qui peut écrire son statebag : le serveur retient la valeur qu'il
        a publiée sur chaque ped (avant l'écriture) et remet la sienne quand une autre apparaît, après un délai de
        regroupement, puis de plus en plus espacée si elle ne revient pas égale (shared/held.lua). Une main écrite par
        un client sur une autre entité qu'il possède (ped non suivi, véhicule…) est remise à rien. Les clients
        n'affichent de toute façon qu'un objet déclaré tenable, sur un ped de joueur.
    Dépendances : shared/constants.lua, shared/held.lua, config.lua, server/core.lua
]]

local type, pairs, next, tostring = type, pairs, next, tostring
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local GetPlayerPed, DoesEntityExist, DoesPlayerExist, Entity = GetPlayerPed, DoesEntityExist, DoesPlayerExist, Entity
local NetworkGetNetworkIdFromEntity, NetworkGetEntityFromNetworkId, NetworkGetEntityOwner =
    NetworkGetNetworkIdFromEntity, NetworkGetEntityFromNetworkId, NetworkGetEntityOwner

local held = VavaInventory.held
local cfg = VavaInventory.config.hands
local HELD_STATE = VavaInventory.HELD_STATE
local NO_ENTITY = 0

local pedState = {}
VavaInventory.pedState = pedState

---@class vAvA.HeldPublication
---@field value table   { id, item } : ce que le joueur tient
---@field ped integer   ped où la valeur est écrite (0 : aucun encore)
---@field netId? integer  numéro réseau de ce ped
---@field streak integer  remises de la garde depuis la dernière publication

---@type table<integer, vAvA.HeldPublication>  source → main publiée ; une entrée tant que le joueur tient quelque chose
local bySource = {}
-- numéro réseau d'un ped → source du porteur dont la main y est écrite
local byNet = {}
-- numéro réseau → true : remise programmée (une minuterie par entité)
local scheduled = {}
-- source → instant du dernier avertissement en console
local warnedAt = {}
local sweeping = false

--- Valeur que le serveur a écrite sur cette entité (nil : aucune, donc rien n'y est attendu).
---@param netId integer
---@return table|nil value
---@return vAvA.HeldPublication|nil entry
local function expected(netId)
    local src = byNet[netId]
    local entry = src and bySource[src]
    if entry and entry.netId == netId then return entry.value, entry end
    return nil, nil
end

--- Écrit la main sur un ped, sauf si son statebag la porte déjà (aucun envoi inutile).
---@param ped integer
---@param value table|nil
local function write(ped, value)
    local state = Entity(ped).state
    if held.same(state[HELD_STATE], value) then return end
    state:set(HELD_STATE, value, true)
end

--- Met la publication d'un joueur sur son ped courant, et s'assure que son statebag la porte : un nouveau ped (autre
--- entité, ou même handle avec un autre numéro réseau) est suivi à la place de l'ancien, qui est vidé s'il existe encore
--- sous le même numéro. La valeur est retenue avant l'écriture : la garde reconnaît celle du serveur. Rien n'est envoyé
--- quand le statebag porte déjà la valeur.
---@param src integer
---@param entry vAvA.HeldPublication
---@param ped integer
local function place(src, entry, ped)
    local netId = ped ~= NO_ENTITY and DoesEntityExist(ped) and NetworkGetNetworkIdFromEntity(ped) or nil
    if ped ~= entry.ped or netId ~= entry.netId then
        local old, oldNet = entry.ped, entry.netId
        if oldNet and byNet[oldNet] == src then
            byNet[oldNet] = nil
            -- même entité qu'à l'écriture (un handle ou un numéro réseau peut être redonné) : sinon on n'y touche pas
            if old ~= ped and old ~= NO_ENTITY and DoesEntityExist(old) and NetworkGetNetworkIdFromEntity(old) == oldNet then
                write(old, nil)
            end
        end
        entry.ped, entry.netId = ped, netId
        if netId then byNet[netId] = src end
    end
    if netId then write(ped, entry.value) end
end

--- Contrôle lent : un porteur dont le ped a changé (réapparition, modèle changé) voit sa main réécrite sur le nouveau,
--- et un statebag qui l'aurait perdue la retrouve. Boucle serveur justifiée : quelques natives et une lecture locale du
--- statebag par porteur toutes les pedCheckMs, s'arrête quand plus personne ne tient rien ; aucun envoi tant que le
--- ped porte sa main.
local function sweep()
    while next(bySource) ~= nil do
        Wait(cfg.pedCheckMs)
        for src, entry in pairs(bySource) do
            if not DoesPlayerExist(src) then
                -- parti sans déchargement vu par ce module : oublié (retirer pendant pairs est permis)
                pedState.forget(src)
            else
                place(src, entry, GetPlayerPed(src))
            end
        end
    end
    sweeping = false
end

--- Publie ce que tient un joueur (nil : mains vides). Écrit sur son ped courant ; sans ped, le contrôle lent l'écrira
--- dès qu'il en aura un.
---@param src integer
---@param value table|nil  { id, item }
function pedState.set(src, value)
    local entry = bySource[src]
    if value == nil then
        if entry then
            bySource[src] = nil
            if entry.netId and byNet[entry.netId] == src then byNet[entry.netId] = nil end
        end
        -- vidé là où il est, s'il porte encore quelque chose (rien n'est envoyé sinon)
        local ped = GetPlayerPed(src)
        if ped ~= NO_ENTITY and DoesEntityExist(ped) then write(ped, nil) end
        return
    end
    if not entry then
        entry = { value = value, ped = NO_ENTITY, streak = 0 }
        bySource[src] = entry
    end
    -- toute publication remet à zéro le compte des remises
    entry.value, entry.streak = value, 0
    place(src, entry, GetPlayerPed(src))
    if not sweeping then
        sweeping = true
        CreateThread(sweep)
    end
end

--- Oublie un joueur parti : rien n'est plus écrit pour lui (son ped disparaît avec lui).
---@param src integer
function pedState.forget(src)
    local entry = bySource[src]
    bySource[src] = nil
    warnedAt[src] = nil
    if entry and entry.netId and byNet[entry.netId] == src then byNet[entry.netId] = nil end
end

---@param netId integer
---@param entity integer
---@param restored boolean  vrai si la valeur du serveur a été remise sur un ped suivi
local function warn(netId, entity, restored)
    local owner = NetworkGetEntityOwner(entity)
    local now = GetGameTimer()
    local last = warnedAt[owner]
    if last and now - last < cfg.guardWarnMs then return end
    warnedAt[owner] = now
    VavaInventory.log.warn('joueur %s : main réécrite par son client sur l\'entité réseau %d, %s', tostring(owner),
        netId, restored and 'valeur du serveur remise' or 'effacée')
end

--- Remet la valeur du serveur sur une entité dont la main a été réécrite, après le délai de regroupement.
---@param netId integer
local function correct(netId)
    scheduled[netId] = nil
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == NO_ENTITY or not DoesEntityExist(entity) then return end
    local value, entry = expected(netId)
    local state = Entity(entity).state
    if held.same(state[HELD_STATE], value) then return end
    -- compté AVANT l'écriture : si elle revient différente, la remise suivante est déjà espacée
    if entry then entry.streak = entry.streak + 1 end
    state:set(HELD_STATE, value, true)
    if not entry or entry.streak <= cfg.guardMaxCorrections then warn(netId, entity, entry ~= nil) end
end

--- Garde : appelée à chaque changement, vu par le serveur, de la main sur un statebag. Ne tranche pas sur l'origine :
--- toute valeur différente de celle écrite par le serveur est remise, jamais pendant l'appel (la valeur n'y est pas
--- encore appliquée).
---@param bagName any
---@param _ any  clé (filtrée par le gestionnaire)
---@param value any
local function onChange(bagName, _, value)
    local netId = held.netIdOf(bagName)
    if not netId or scheduled[netId] then return end
    local want, entry = expected(netId)
    if held.same(value, want) then return end
    scheduled[netId] = true
    local streak = entry and entry.streak or 0
    if entry and streak == cfg.guardMaxCorrections then
        VavaInventory.log.warn('entité réseau %d : main remise %d fois de suite sans nouvelle publication, remises'
            .. ' espacées jusqu\'à %d ms', netId, streak, cfg.guardMaxDelayMs)
    end
    SetTimeout(held.guardDelay(streak, cfg), function() correct(netId) end)
end

--- Branche la garde. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function pedState.start()
    local native = AddStateBagChangeHandler
    if type(native) ~= 'function' then return false, 'AddStateBagChangeHandler indisponible' end
    -- filtré sur la clé : ni les autres statebags d'entités, ni GlobalState n'atteignent ce gestionnaire
    native(HELD_STATE, nil, onChange)
    return true
end
