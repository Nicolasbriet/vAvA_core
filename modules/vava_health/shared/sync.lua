--[[
    vava_health/shared/sync.lua
    Rôle : règles pures de l'accord entre la vie du serveur (qui fait foi) et le ped lu côté serveur (spec T-110
           § 7.3) :
      - fenêtre d'application : après un ordre de vie (SET, REVIVE, RESPAWN), le ped n'est pas lu le temps que le
        client l'applique (délai fixe plus deux fois le ping, borné) ;
      - jugement d'une lecture : à attendre, d'accord, perte native (ped plus bas), ou client au-dessus (à corriger) ;
      - porte d'apparition : apparition confirmée, ou lue d'office quand le client ne la confirme pas.
      Aucun état.
    Dépendances : shared/constants.lua
]]

local type, min = type, math.min

local sync = {}
VavaHealth.sync = sync

--- Heure jusqu'à laquelle la lecture du ped est ignorée après un ordre de vie.
---@param now integer
---@param applyMs integer
---@param ping integer     ping du joueur (ms)
---@param maxPingMs integer
---@return integer
function sync.window(now, applyMs, ping, maxPingMs)
    if type(ping) ~= 'number' or ping ~= ping or ping < 0 then ping = 0 end
    return now + applyMs + min(2 * ping, maxPingMs)
end

--- Jugement d'une lecture du ped (parts de 0 à 1) : 'wait' (avant syncUntil), 'ok' (écart dans la tolérance),
--- 'loss' et l'écart (ped plus bas : perte native), 'above' (ped plus haut : client en retard ou modifié).
---@param observed number
---@param reference number
---@param now integer
---@param syncUntil integer
---@param tolerance number
---@return string verdict
---@return number|nil gap
function sync.judge(observed, reference, now, syncUntil, tolerance)
    if now < syncUntil then return 'wait' end
    local gap = reference - observed
    -- petite marge de calcul : un écart égal à la tolérance reste d'accord
    if gap <= tolerance + 1e-9 and -gap <= tolerance + 1e-9 then return 'ok' end
    if gap > 0 then return 'loss', gap end
    return 'above'
end

--- Porte d'apparition : 'read' (confirmée), 'forced' (non confirmée, délai passé depuis l'ordre, ped présent),
--- 'wait'.
---@param entry { spawned: boolean, spawnOrderedAt: integer|nil }
---@param now integer
---@param pedExists boolean
---@param confirmTimeoutMs integer
---@return string
function sync.spawnGate(entry, now, pedExists, confirmTimeoutMs)
    if entry.spawned then return 'read' end
    local ordered = entry.spawnOrderedAt
    if ordered and pedExists and now - ordered >= confirmTimeoutMs then return 'forced' end
    return 'wait'
end
