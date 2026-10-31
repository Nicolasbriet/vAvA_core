--[[
    vava_combat/client/defense.lua
    Rôle : touche R (appui : parade ; maintenue : garde ; relâchée : garde abaissée) et Espace (pas de côté),
           prédiction sans décision ; aucune boucle (tick appelé par la boucle du mode combat).
    Dépendances : config_client.lua, client/core.lua, client/hands.lua, client/attack.lua
]]

local ipairs, abs, max = ipairs, math.abs, math.max
local CreateThread, GetGameTimer, GetControlNormal, DisableControlAction =
    CreateThread, GetGameTimer, GetControlNormal, DisableControlAction

local core = VavaCombat.core
if not core then return end

local dcfg = VavaCombat.config.defense
local hands = VavaCombat.hands
local attack = VavaCombat.attack
local LOWER = VavaCombat.RPC.LOWER
-- part d'un axe de déplacement au-delà de laquelle le pas de côté prend sa direction
local DEAD_ZONE = 0.3

local defense = {}
VavaCombat.stance = defense

-- R maintenue ; garde demandée ou levée (geste local) ; parade de cet appui ; garde refusée : plus d'essai avant un appui
local held, guard, parry, retry = false, nil, nil, false

--- Ferme le cycle local d'une garde comme le serveur (tenue minimale, récupération).
---@param swing table
---@param now integer
local function close(swing, now)
    if swing.closeAt then return end
    local p = swing.def.phases
    swing.closeAt = max(now, swing.openAt + p.active)
    swing.endAt = swing.closeAt + p.recovery
end

--- Garde abaissée : geste coupé, cycle fermé, `lower` demandé si `send`.
---@param send boolean
local function lowerGuard(send)
    local swing = guard
    guard = nil
    hands.stopGesture(swing.gesture)
    close(swing, GetGameTimer())
    if send then CreateThread(function() core.rpc.call(LOWER) end) end
end

--- R enfoncée (mode éveillé et actif) : parade aussitôt si elle peut partir.
function defense.press()
    held, retry = true, true
    if guard then return end
    local now = GetGameTimer()
    local id = attack.choose('parade', now)
    parry = id and attack.start(id, now) or nil
end

--- R relâchée : garde abaissée si elle était levée ou demandée.
function defense.release()
    held = false
    if guard then lowerGuard(true) end
end

--- Garde tombée (mode endormi ou inactif : `lower` envoyé ; chancellement, garde brisée : non, le serveur l'a fermée).
---@param send boolean
function defense.drop(send)
    held = false
    if guard then lowerGuard(send) end
end

--- Vrai si la garde est levée ou demandée (aucune attaque ne part).
---@return boolean
function defense.guarding()
    return guard ~= nil
end

--- Espace (mode actif) : pas de côté, direction lue une fois (gauche, droite, avant ; sinon le geste de la technique).
function defense.dodge()
    if guard then return end
    local now = GetGameTimer()
    local id = attack.choose('esquive', now)
    if not id then return end
    local x, y = GetControlNormal(0, 30), GetControlNormal(0, 31)
    local side = nil
    if abs(x) > DEAD_ZONE and abs(x) >= abs(y) then
        side = x < 0 and 'gauche' or 'droite'
    elseif y < -DEAD_ZONE then
        side = 'avant'
    end
    attack.start(id, now, side and dcfg.dodgeGestures[side] or nil)
end

--- Une image du mode combat actif : R maintenue après la fenêtre de parade → garde demandée ; garde : contrôles coupés.
---@param now integer
function defense.tick(now)
    if guard then
        for _, control in ipairs(dcfg.guardBlocked) do DisableControlAction(0, control, true) end
        return
    end
    if not held or not retry or (parry and parry == attack.current() and now < parry.closeAt) then return end
    local id = attack.choose('blocage', now, true)
    if not id then return end
    local swing = attack.start(id, now)
    swing.onRefused = function()
        if guard == swing then guard = nil end
        retry = false
    end
    guard = swing
end
