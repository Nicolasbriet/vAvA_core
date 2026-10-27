--[[
    vava_magic/server/mana.lua
    Rôle : mana des mages en jeu, décidée par le serveur et jamais sauvegardée (pleine à l'arrivée). Aucune boucle :
           la régénération (`regenPoints` toutes les `regenMs`) se calcule à la demande depuis le dernier changement.
           À chaque changement, le joueur reçoit la valeur et le rythme de régénération : son client anime la
           remontée lui-même, sans aucun envoi périodique.
    Dépendances : shared/constants.lua, config.lua
]]

local min = math.min
local GetGameTimer, TriggerClientEvent = GetGameTimer, TriggerClientEvent

local cfg = VavaMagic.config.mana
local EVENTS = VavaMagic.EVENTS
local MAX, POINTS, PERIOD = cfg.max, cfg.regenPoints, cfg.regenMs

local mana = {}
VavaMagic.mana = mana

mana.MAX = MAX

---@type table<integer, { value: integer, since: integer }>  valeur au moment `since`
local pools = {}

--- Ajoute les périodes de régénération écoulées, en gardant le rythme commencé.
local function settle(pool, now)
    if pool.value >= MAX then
        pool.value, pool.since = MAX, now
        return
    end
    local periods = (now - pool.since) // PERIOD
    if periods > 0 then
        pool.value = pool.value + periods * POINTS
        pool.since = pool.since + periods * PERIOD
        if pool.value >= MAX then pool.value, pool.since = MAX, now end
    end
end

--- Envoie la mana au joueur : valeur, maximum, rythme et temps écoulé depuis le début de la période en cours.
---@param src integer
function mana.push(src)
    local pool = pools[src]
    if not pool then return end
    local now = GetGameTimer()
    settle(pool, now)
    TriggerClientEvent(EVENTS.MANA, src, pool.value, MAX, POINTS, PERIOD, now - pool.since)
end

--- Un mage arrive (ou le devient) : mana pleine.
---@param src integer
function mana.start(src)
    pools[src] = { value = MAX, since = GetGameTimer() }
    mana.push(src)
end

---@param src integer
function mana.stop(src)
    pools[src] = nil
end

---@param src integer
---@return integer
function mana.current(src)
    local pool = pools[src]
    if not pool then return 0 end
    settle(pool, GetGameTimer())
    return pool.value
end

--- Retire `amount` points s'il les a. Renvoie vrai si c'est fait.
---@param src integer
---@param amount integer
---@return boolean
function mana.spend(src, amount)
    local pool = pools[src]
    if not pool then return false end
    settle(pool, GetGameTimer())
    if pool.value < amount then return false end
    pool.value = pool.value - amount
    mana.push(src)
    return true
end

--- Rend des points (remboursement), sans dépasser le maximum.
---@param src integer
---@param amount integer
function mana.give(src, amount)
    local pool = pools[src]
    if not pool or amount <= 0 then return end
    local now = GetGameTimer()
    settle(pool, now)
    pool.value = min(MAX, pool.value + amount)
    if pool.value >= MAX then pool.since = now end
    mana.push(src)
end

---@param src integer
---@return boolean  faux si le joueur n'a pas de mana (pas mage)
function mana.refill(src)
    local pool = pools[src]
    if not pool then return false end
    pool.value, pool.since = MAX, GetGameTimer()
    mana.push(src)
    return true
end
