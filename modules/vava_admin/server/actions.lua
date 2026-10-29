--[[
    vava_admin/server/actions.lua
    Rôle : actions du Conseil. Chacune reçoit un acteur et une cible déjà vérifiés (droit, rang : server/rpc.lua) et
           renvoie ok, résultat (pour le panneau), détails (pour le journal). Déplacer et geler passent par les
           natives serveur (OneSync) : rien n'est demandé au client. Les modules administrés (santé, besoins,
           inventaire) sont appelés de façon isolée et restent facultatifs.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/ranks.lua, server/store.lua,
                  server/bans.lua, server/players.lua, server/spectate.lua
]]

local type, pairs, ipairs, tonumber, tostring, sort = type, pairs, ipairs, tonumber, tostring, table.sort
local GetPlayerPed, GetEntityCoords, SetEntityCoords, FreezeEntityPosition, DropPlayer =
    GetPlayerPed, GetEntityCoords, SetEntityCoords, FreezeEntityPosition, DropPlayer
local TriggerClientEvent = TriggerClientEvent

local ranks = VavaAdmin.ranks
local store = VavaAdmin.store
local bans = VavaAdmin.bans
local players = VavaAdmin.players
local spectate = VavaAdmin.spectate
local call = VavaAdmin.call
local cfg = VavaAdmin.config
local messages = cfg.messages
local EVENTS = VavaAdmin.EVENTS
-- définitions des objets (libellés), registre du core tenu par vava_inventory
local ITEMS_REGISTRY = 'vava_inventory:items'

local actions = {}
VavaAdmin.actions = actions

---@type table<integer, vector3>  position d'un joueur avant son dernier déplacement par le Conseil
local previous = {}

---@param src integer
---@return vector3|nil
local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

---@param src integer
---@param coords vector3|table
---@param offset number
local function place(src, coords, offset)
    SetEntityCoords(GetPlayerPed(src), coords.x + offset, coords.y, coords.z, false, false, false, false)
end

---@param src integer|nil
---@param text string
---@param kind string
---@param title? string
local function tell(src, text, kind, title)
    if src then TriggerClientEvent(EVENTS.NOTIFY, src, { text = text, kind = kind, title = title }) end
end

---@param hours integer
---@return string
local function duration(hours)
    return hours == 0 and 'définitif' or (hours .. ' h')
end

-- Déplacements ---------------------------------------------------------------------------------------------------

--- Rejoint le joueur (« goto », mot réservé en Lua).
function actions.reach(actor, target)
    if not actor.source then return false, 'no_body' end
    local coords = coordsOf(target.source)
    if not coords or not coordsOf(actor.source) then return false, 'no_ped' end
    previous[actor.source] = coordsOf(actor.source)
    place(actor.source, coords, cfg.teleportOffset)
    return true
end

function actions.bring(actor, target)
    if not actor.source then return false, 'no_body' end
    local coords = coordsOf(actor.source)
    if not coords or not coordsOf(target.source) then return false, 'no_ped' end
    previous[target.source] = coordsOf(target.source)
    place(target.source, coords, cfg.teleportOffset)
    return true
end

--- Envoie le joueur auprès d'un autre (depuis le panneau web, l'acteur n'a pas de corps dans le monde).
function actions.moveToPlayer(_, target, destinationId)
    local destination = players.resolve(destinationId)
    if not destination then return false, 'destination_not_found' end
    if destination.source == target.source then return false, 'self' end
    local coords = coordsOf(destination.source)
    if not coords or not coordsOf(target.source) then return false, 'no_ped' end
    previous[target.source] = coordsOf(target.source)
    place(target.source, coords, cfg.teleportOffset)
    return true, nil, { vers = destination.label }
end

--- Envoie le joueur à des coordonnées.
function actions.moveToCoords(_, target, x, y, z)
    if not coordsOf(target.source) then return false, 'no_ped' end
    previous[target.source] = coordsOf(target.source)
    place(target.source, { x = x, y = y, z = z }, 0)
    return true, nil, { vers = ('%.1f, %.1f, %.1f'):format(x, y, z) }
end

--- Renvoie le joueur (ou l'acteur lui-même) là où il était avant son dernier déplacement par le Conseil.
function actions.sendBack(_, target)
    local coords = previous[target.source]
    if not coords then return false, 'no_previous' end
    if not coordsOf(target.source) then return false, 'no_ped' end
    previous[target.source] = nil
    place(target.source, coords, 0)
    return true
end

function actions.freeze(_, target, state)
    local ped = GetPlayerPed(target.source)
    if ped == 0 then return false, 'no_ped' end
    FreezeEntityPosition(ped, state)
    players.frozen[target.source] = state or nil
    tell(target.source, state and messages.frozen or messages.unfrozen, state and 'warning' or 'info')
    return true, nil, { etat = state and 'immobilisé' or 'libéré' }
end

--- Arrêt du module : chaque joueur immobilisé par le Conseil est libéré. L'état « immobilisé » ne vit qu'en mémoire :
--- un joueur laissé figé après l'arrêt serait sans recours (aucun Registre pour le libérer, fiche « libre » au
--- redémarrage). Renvoie le nombre de joueurs libérés.
---@return integer
function actions.releaseAll()
    local count = 0
    for src in pairs(players.frozen) do
        local ped = GetPlayerPed(src)
        if ped ~= 0 then FreezeEntityPosition(ped, false) end
        tell(src, messages.unfrozen, 'info')
        count = count + 1
    end
    for src in pairs(players.frozen) do players.frozen[src] = nil end
    return count
end

-- Soins ----------------------------------------------------------------------------------------------------------

--- Relève (s'il est à terre) ou rend toute sa vie.
function actions.heal(_, target)
    local ok, downed = call('vava_health', 'isDowned', target.source)
    if not ok then return false, 'unavailable' end
    local done, code
    if downed then
        ok, done, code = call('vava_health', 'revive', target.source, 1.0)
    else
        ok, done, code = call('vava_health', 'setHealth', target.source, 1.0)
    end
    if not ok or not done then return false, code or 'unavailable' end
    return true, nil, { releve = downed and 'oui' or 'non' }
end

function actions.feed(_, target)
    local ok, done, code = call('vava_needs', 'set', target.source, { hunger = 100, thirst = 100 })
    if not ok or not done then return false, code or 'unavailable' end
    return true
end

-- Paroles et sanctions -------------------------------------------------------------------------------------------

function actions.message(_, target, text)
    tell(target.source, text, 'info', messages.messageTitle)
    return true, nil, { message = text }
end

function actions.warn(actor, target, reason)
    local id, err = store.addWarning(target.accountId, reason, actor.label)
    if not id then
        VavaAdmin.log.error('avertissement non écrit : %s', tostring(err))
        return false, 'db_error'
    end
    tell(target.source, messages.warned:format(reason), 'danger')
    return true, nil, { motif = reason }
end

function actions.kick(_, target, reason)
    DropPlayer(tostring(target.source), messages.kicked:format(reason))
    return true, nil, { motif = reason }
end

--- Bannit un compte (connecté ou non) ; un joueur connecté est expulsé avec le motif et la fin du ban.
---@param actor vAvA.AdminActor
---@param accountId integer
---@param label string
---@param hours integer  0 = définitif
---@param reason string
---@param src? integer   joueur connecté sur ce compte
---@return boolean ok
---@return string|nil code
---@return table|nil details
function actions.banAccount(actor, accountId, label, hours, reason, src)
    if not ranks.canBan(actor.rank, hours) then return false, 'ban_too_long' end
    local id, err = bans.ban(actor, accountId, label, hours, reason)
    if not id then
        VavaAdmin.log.error('ban non écrit : %s', tostring(err))
        return false, 'db_error'
    end
    if src then
        local ban = bans.active(accountId) or { id = id, reason = reason }
        DropPlayer(tostring(src), bans.message(ban))
    end
    return true, id, { motif = reason, duree = duration(hours), ban = id }
end

function actions.ban(actor, target, hours, reason)
    return actions.banAccount(actor, target.accountId, target.label, hours, reason, target.source)
end

-- Inventaire et observation --------------------------------------------------------------------------------------

--- Ouvre l'inventaire du joueur à l'acteur (dans l'interface d'inventaire, à côté du sien).
function actions.inventory(actor, target)
    if not actor.source then return false, 'no_body' end
    local ok, containerId, code = call('vava_inventory', 'containerOf', target.source)
    if not ok or not containerId then return false, code or 'unavailable' end
    local opened, openCode
    ok, opened, openCode = call('vava_inventory', 'open', actor.source, containerId)
    if not ok or not opened then return false, openCode or 'unavailable' end
    return true
end

--- Contenu de l'inventaire du joueur, en lecture (panneau web) : liste { item, label, quantity }, par objet.
function actions.inventoryView(_, target)
    local ok, list, code = call('vava_inventory', 'getItems', target.source)
    if not ok or type(list) ~= 'table' then return false, code or 'unavailable' end
    local totals, order = {}, {}
    for _, instance in pairs(list) do
        local item = type(instance) == 'table' and instance.item
        if type(item) == 'string' then
            if not totals[item] then
                totals[item] = 0
                order[#order + 1] = item
            end
            totals[item] = totals[item] + (tonumber(instance.quantity) or 0)
        end
    end
    sort(order)
    local registry = VavaAdmin.core.registry
    local out = {}
    for i, item in ipairs(order) do
        local def = registry.get(ITEMS_REGISTRY, item)
        out[i] = { item = item, label = def and def.label or item, quantity = totals[item] }
    end
    return true, out
end

--- Regarder l'écran du joueur (panneau web) : accordé et inscrit au journal ici, l'image passe par le pont.
function actions.watchScreen(_, target)
    if not coordsOf(target.source) then return false, 'no_ped' end
    return true, { source = target.source, label = target.label }
end

function actions.give(_, target, item, quantity)
    local ok, done, code = call('vava_inventory', 'add', target.source, item, quantity)
    if not ok or not done then return false, code or 'unavailable' end
    return true, nil, { objet = item, quantite = quantity }
end

--- Observation : le client de l'acteur fait le reste (il doit s'approcher pour recevoir le joueur, OneSync). Sa place
--- de départ est gardée par le serveur, au cas où il partirait avant la fin (server/spectate.lua).
function actions.spectate(actor, target)
    if not actor.source then return false, 'no_body' end
    local coords = coordsOf(target.source)
    if not coords then return false, 'no_ped' end
    spectate.begin(actor.source)
    return true, { source = target.source, label = target.label, x = coords.x, y = coords.y, z = coords.z }
end

--- Le joueur parti : sa position mémorisée ne sert plus.
---@param src integer
function actions.forget(src)
    previous[src] = nil
end
