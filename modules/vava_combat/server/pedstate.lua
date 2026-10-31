--[[
    vava_combat/server/pedstate.lua
    Rôle : publication du bouclier accroché sur le statebag du ped du porteur, et garde de ce statebag (patron de
           vava_inventory/server/pedstate.lua).
      - Valeur courte { id, item } (ou rien), sous la clé VavaCombat.SHIELD_STATE, répliquée : OneSync ne l'envoie
        qu'aux joueurs qui ont ce ped à portée, et la renvoie à chacun quand le ped apparaît chez lui. Le placement et la
        position (bras ou dos) ne sont jamais dans la valeur : chaque client les lit dans sa config et d'après la main
        du porteur.
      - Un statebag d'entité meurt avec elle : un contrôle lent compare le ped de chaque porteur à celui où la valeur
        est écrite et la réécrit sur le nouveau ; il ne tourne que tant qu'un bouclier est accroché.
      - Le ped d'un joueur est possédé par son client, qui peut écrire son statebag : le serveur retient la valeur qu'il
        a publiée sur chaque ped et remet la sienne après un délai de regroupement, de plus en plus espacé si elle ne
        revient pas égale (shared/shield.lua). Une valeur écrite sur une entité non suivie est effacée.
    Dépendances : shared/constants.lua, shared/shield.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, next, tostring, tonumber = type, pairs, ipairs, next, tostring, tonumber
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local GetPlayers, GetPlayerPed, DoesEntityExist, DoesPlayerExist, Entity = GetPlayers, GetPlayerPed, DoesEntityExist, DoesPlayerExist, Entity
local NetworkGetNetworkIdFromEntity, NetworkGetEntityFromNetworkId, NetworkGetEntityOwner =
    NetworkGetNetworkIdFromEntity, NetworkGetEntityFromNetworkId, NetworkGetEntityOwner

local shield = VavaCombat.shield
local cfg = VavaCombat.config.shield
local SHIELD_STATE = VavaCombat.SHIELD_STATE
local NO_ENTITY = 0

local pedState = {}
VavaCombat.pedState = pedState

---@class vAvA.ShieldPublication
---@field value table   { id, item } : bouclier accroché
---@field ped integer   ped où la valeur est écrite (0 : aucun encore)
---@field netId? integer  numéro réseau de ce ped
---@field streak integer  remises de la garde depuis la dernière publication

---@type table<integer, vAvA.ShieldPublication>  source → publication ; une entrée tant qu'un bouclier est accroché
local bySource = {}
-- numéro réseau d'un ped → source du porteur dont la valeur y est écrite
local byNet = {}
-- numéro réseau → true : remise programmée (une minuterie par entité)
local scheduled = {}
-- source → instant du dernier avertissement en console
local warnedAt = {}
local sweeping = false

--- Valeur que le serveur a écrite sur cette entité (nil : aucune, donc rien n'y est attendu).
---@param netId integer
---@return table|nil value
---@return vAvA.ShieldPublication|nil entry
local function expected(netId)
    local src = byNet[netId]
    local entry = src and bySource[src]
    if entry and entry.netId == netId then return entry.value, entry end
    return nil, nil
end

--- Écrit la valeur sur un ped, sauf si son statebag la porte déjà (aucun envoi inutile).
---@param ped integer
---@param value table|nil
local function write(ped, value)
    local state = Entity(ped).state
    if shield.same(state[SHIELD_STATE], value) then return end
    state:set(SHIELD_STATE, value, true)
end

--- Met la publication d'un joueur sur son ped courant ; un nouveau ped est suivi à la place de l'ancien, vidé s'il
--- existe encore sous le même numéro. La valeur est retenue avant l'écriture : la garde reconnaît celle du serveur.
---@param src integer
---@param entry vAvA.ShieldPublication
---@param ped integer
local function place(src, entry, ped)
    local netId = ped ~= NO_ENTITY and DoesEntityExist(ped) and NetworkGetNetworkIdFromEntity(ped) or nil
    if ped ~= entry.ped or netId ~= entry.netId then
        local old, oldNet = entry.ped, entry.netId
        if oldNet and byNet[oldNet] == src then
            byNet[oldNet] = nil
            if old ~= ped and old ~= NO_ENTITY and DoesEntityExist(old) and NetworkGetNetworkIdFromEntity(old) == oldNet then
                write(old, nil)
            end
        end
        entry.ped, entry.netId = ped, netId
        if netId then byNet[netId] = src end
    end
    if netId then write(ped, entry.value) end
end

--- Contrôle lent : un porteur dont le ped a changé voit sa valeur réécrite sur le nouveau. Boucle serveur justifiée :
--- quelques natives par porteur toutes les pedCheckMs, s'arrête quand plus aucun bouclier n'est accroché ; aucun envoi
--- tant que le ped porte sa valeur.
local function sweep()
    while next(bySource) ~= nil do
        Wait(cfg.pedCheckMs)
        for src, entry in pairs(bySource) do
            if not DoesPlayerExist(src) then
                pedState.forget(src)
            else
                place(src, entry, GetPlayerPed(src))
            end
        end
    end
    sweeping = false
end

--- Publie le bouclier accroché d'un joueur (nil : rien d'accroché).
---@param src integer
---@param value table|nil  { id, item }
function pedState.set(src, value)
    local entry = bySource[src]
    if value == nil then
        if entry then
            bySource[src] = nil
            if entry.netId and byNet[entry.netId] == src then byNet[entry.netId] = nil end
        end
        local ped = GetPlayerPed(src)
        if ped ~= NO_ENTITY and DoesEntityExist(ped) then write(ped, nil) end
        return
    end
    if not entry then
        entry = { value = value, ped = NO_ENTITY, streak = 0 }
        bySource[src] = entry
    end
    entry.value, entry.streak = value, 0
    place(src, entry, GetPlayerPed(src))
    if not sweeping then
        sweeping = true
        CreateThread(sweep)
    end
end

--- Oublie un joueur parti : rien n'est plus écrit pour lui.
---@param src integer
function pedState.forget(src)
    local entry = bySource[src]
    bySource[src] = nil
    warnedAt[src] = nil
    if entry and entry.netId and byNet[entry.netId] == src then byNet[entry.netId] = nil end
end

---@param netId integer
---@param entity integer
---@param restored boolean
local function warn(netId, entity, restored)
    local owner = NetworkGetEntityOwner(entity)
    local now = GetGameTimer()
    local last = warnedAt[owner]
    if last and now - last < cfg.guardWarnMs then return end
    warnedAt[owner] = now
    VavaCombat.log.warn('joueur %s : bouclier réécrit par son client sur l\'entité réseau %d, %s', tostring(owner),
        netId, restored and 'valeur du serveur remise' or 'effacé')
end

--- Remet la valeur du serveur sur une entité dont le statebag a été réécrit, après le délai de regroupement.
---@param netId integer
local function correct(netId)
    scheduled[netId] = nil
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == NO_ENTITY or not DoesEntityExist(entity) then return end
    local value, entry = expected(netId)
    if entry and entity ~= entry.ped then value, entry = nil, nil end
    local state = Entity(entity).state
    if shield.same(state[SHIELD_STATE], value) then return end
    if entry then entry.streak = entry.streak + 1 end
    state:set(SHIELD_STATE, value, true)
    if not entry or entry.streak <= cfg.guardMaxCorrections then warn(netId, entity, entry ~= nil) end
end

--- Garde : appelée à chaque changement, vu par le serveur, du statebag du bouclier. Toute valeur différente de celle
--- écrite par le serveur est remise, jamais pendant l'appel.
---@param bagName any
---@param _ any
---@param value any
local function onChange(bagName, _, value)
    local netId = shield.netIdOf(bagName)
    if not netId or scheduled[netId] then return end
    local want, entry = expected(netId)
    if shield.same(value, want) then return end
    scheduled[netId] = true
    local streak = entry and entry.streak or 0
    if entry and streak == cfg.guardMaxCorrections then
        VavaCombat.log.warn('entité réseau %d : bouclier remis %d fois de suite sans nouvelle publication, remises'
            .. ' espacées jusqu\'à %d ms', netId, streak, cfg.guardMaxDelayMs)
    end
    SetTimeout(shield.guardDelay(streak, cfg), function() correct(netId) end)
end

--- Vide le bouclier du ped de chaque joueur connecté, là où il en porte un.
local function clearAllPeds()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = src and GetPlayerPed(src) or NO_ENTITY
        if ped ~= NO_ENTITY and DoesEntityExist(ped) then write(ped, nil) end
    end
end

--- Branche la garde, puis vide les peds (une valeur laissée par une instance précédente du module ne doit rien montrer
--- tant que les boucliers n'ont pas été repris). Appelé pendant le setup, avant la reprise.
---@return boolean ok
---@return string|nil err
function pedState.start()
    local native = AddStateBagChangeHandler
    if type(native) ~= 'function' then return false, 'AddStateBagChangeHandler indisponible' end
    native(SHIELD_STATE, nil, onChange)
    clearAllPeds()
    return true
end

--- Arrêt du module : plus rien n'est publié ni gardé, et aucun ped ne garde un bouclier.
function pedState.stop()
    clearAllPeds()
    bySource, byNet, scheduled, warnedAt = {}, {}, {}, {}
end
