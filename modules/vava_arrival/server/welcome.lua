--[[
    vava_arrival/server/welcome.lua
    Rôle : l'arrivée à chaque apparition d'un personnage suivi : dotation puis accueil, dans un thread (une seule
           arrivée à la fois par personnage : `busy` pris sans céder la main) ; envoi de l'accueil au SEUL joueur
           concerné (au plus `welcome.maxSends` fois sans accusé, une fois par session), hook vava_arrival:arrived au
           premier envoi ; dotations reprises au retour de l'inventaire (sans second accueil) ; accusé de lecture
           (RPC) ; accueil rejoué par le Conseil.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/store.lua, server/kit.lua
]]

local ipairs, pcall, tostring = ipairs, pcall, tostring
local CreateThread = CreateThread

local bridge = VavaArrival.bridge
local store = VavaArrival.store
local kit = VavaArrival.kit
local rules = VavaArrival.rules
local cfg = VavaArrival.config
local KIT = VavaArrival.KIT
local EVENTS = VavaArrival.EVENTS
local HOOKS = VavaArrival.HOOKS

local welcome = {}
VavaArrival.welcome = welcome

--- Envoie l'accueil d'un nouveau personnage à son seul joueur, si le personnage est toujours le sien, jamais vu, et
--- envoyé moins de `welcome.maxSends` fois. Au premier envoi : hook vava_arrival:arrived.
---@param entry vAvA.ArrivalEntry
---@param kitGiven boolean  afficher la ligne de la dotation
---@return boolean sent
function welcome.send(entry, kitGiven)
    if bridge.ActiveCharacterId(entry.source) ~= entry.characterId then return false end
    if entry.welcomedAt ~= nil or entry.welcomeSends >= cfg.welcome.maxSends then return false end
    if not bridge.Send(entry.source, EVENTS.WELCOME, kitGiven == true) then return false end
    store.countSend(entry.characterId)
    local first = entry.welcomeSends == 0
    entry.welcomeSends = entry.welcomeSends + 1
    entry.awaitingAck = true
    if first then
        bridge.Emit(HOOKS.ARRIVED, { source = entry.source, characterId = entry.characterId, accountId = entry.accountId, kit = entry.kit })
    end
    return true
end

---@param entry vAvA.ArrivalEntry
---@param plan { kit: boolean, welcome: boolean }
local function run(entry, plan)
    local given = false
    if plan.kit then
        local _
        _, given = kit.claim(entry)
    end
    if plan.welcome then welcome.send(entry, given) end
end

--- Lance l'arrivée d'une entrée (dotation si elle est due, accueil si `withWelcome` et s'il reste à montrer) dans un
--- thread. `busy` est pris ici, sans céder la main : une seconde apparition pendant les attentes de la base ne
--- relance rien.
---@param entry vAvA.ArrivalEntry
---@param withWelcome boolean
---@return boolean started
function welcome.start(entry, withWelcome)
    local plan = rules.plan(entry, cfg.welcome.maxSends)
    if not withWelcome then plan.welcome = false end
    if not plan.kit and not plan.welcome then return false end
    entry.busy = true
    CreateThread(function()
        local ok, err = pcall(run, entry, plan)
        entry.busy = false
        if not ok then VavaArrival.log.error('personnage n° %d : arrivée en erreur : %s', entry.characterId, tostring(err)) end
    end)
    return true
end

--- Hook core:character:spawned (chaque apparition, réanimation comprise).
---@param payload { source: integer, characterId: integer }
function welcome.onSpawned(payload)
    local entry = store.entry(payload.characterId)
    if not entry or entry.source ~= payload.source then return end
    entry.spawned = true
    welcome.start(entry, true)
end

--- Retour de vava_inventory : dotations encore dues reprises pour les personnages apparus, sans renvoyer l'accueil.
function welcome.onInventoryReady()
    for _, entry in ipairs(store.list()) do
        if entry.kit == KIT.DUE and entry.spawned and not entry.busy then welcome.start(entry, false) end
    end
end

--- RPC vava_arrival:welcomed : l'accueil envoyé pendant cette session a été montré. Un client qui accuse sans avoir
--- rien affiché ne fait que se priver de son propre accueil.
---@param source integer
---@return boolean ok
---@return string|nil code  no_character | not_expected | db_error
function welcome.ack(source)
    local characterId = bridge.ActiveCharacterId(source)
    if not characterId then return false, 'no_character' end
    local entry = store.entry(characterId)
    if not entry or entry.source ~= source or not entry.awaitingAck then return false, 'not_expected' end
    entry.awaitingAck = false
    local now = bridge.Now()
    local ok, err = store.ack(characterId, now)
    if not ok then
        -- rien n'est renvoyé cette session ; la base n'a pas l'accusé : l'accueil reviendra à la prochaine
        entry.awaitingAck = true
        VavaArrival.log.warn('personnage n° %d : accusé de l\'accueil non écrit (%s)', characterId, tostring(err))
        return false, 'db_error'
    end
    entry.welcomedAt = now
    return true
end

--- Accueil rejoué par le Conseil (ligne déjà remise à zéro en base, un envoi compté) : envoyé tout de suite, sans la
--- ligne de la dotation et sans hook.
---@param entry vAvA.ArrivalEntry
---@return boolean ok
---@return string|nil code
function welcome.replay(entry)
    if bridge.ActiveCharacterId(entry.source) ~= entry.characterId then return false, 'changed' end
    local ok, code = bridge.Send(entry.source, EVENTS.WELCOME, false)
    if not ok then return false, code end
    entry.welcomedAt, entry.welcomeSends, entry.awaitingAck = nil, 1, true
    return true
end
