--[[
    vava_pause/shared/gate.lua
    Rôle : logique pure de la porte de la bannière, côté client : d'après des faits relus une fois (personnage, écran,
           menu natif, focus, ligotage, blocages posés), la bannière se déploie-t-elle, et sous quelle forme (entière,
           ou réduite à terre : décision 2 du porteur du projet) ? Un refus dit sa raison et s'il est muet ; un même
           refus n'est pas répété avant un délai. Le serveur revérifie à terre, combat et crochets (RPC open).
    Dépendances : shared/constants.lua
]]

local pairs, mathType = pairs, math.type

local gate = {}
VavaPause.gate = gate

-- Refus sans message : l'état se voit déjà à l'écran, ou une autre interface gère son Échap.
local MUTED = { open = true, no_character = true, faded = true, native = true, busy = true }

--- Sortes des blocages posés : { restrained = bool, combat = bool, other = bool }.
---@param blocks table<string, string>  clé du blocage → sorte (restrained | combat | other)
---@return { restrained: boolean, combat: boolean, other: boolean }
function gate.blockKinds(blocks)
    local kinds = { restrained = false, combat = false, other = false }
    for _, kind in pairs(blocks or {}) do
        if kinds[kind] ~= nil then kinds[kind] = true else kinds.other = true end
    end
    return kinds
end

--- Décision d'ouverture. Ordre : open → no_character → faded → native → busy → restrained → combat → blocked. À terre
--- n'est pas un refus : la bannière se déploie réduite (Paramètres du jeu, Quitter, Reprendre).
---@param f { open: boolean, character: boolean, faded: boolean, native: boolean, focused: boolean, now: integer,
---           lastFocusAt: integer|nil, graceMs: integer, cuffed: boolean, downed: boolean, blocks: table|nil }
---@return boolean ok
---@return string reasonOrMode  raison du refus, ou forme : 'full' | 'downed'
---@return boolean|nil muted  refus sans message
function gate.decide(f)
    if f.open then return false, 'open', true end
    if not f.character then return false, 'no_character', true end
    if f.faded then return false, 'faded', true end
    if f.native then return false, 'native', true end
    if f.focused or (f.lastFocusAt and f.now - f.lastFocusAt < f.graceMs) then return false, 'busy', true end
    local kinds = gate.blockKinds(f.blocks)
    if f.cuffed or kinds.restrained then return false, 'restrained', false end
    if kinds.combat then return false, 'combat', false end
    if kinds.other then return false, 'blocked', false end
    return true, f.downed and 'downed' or 'full'
end

-- Refus du serveur gardés par le client (relecture réseau R-1 de T-145) ----------------------------------------------

--- Verdict d'un refus du serveur : valable `remainingMs` (combat : temps restant de la fenêtre, donné par le serveur),
--- sinon `minMs`.
---@param reason string
---@param remainingMs any
---@param now integer
---@param minMs integer
---@return { reason: string, untilMs: integer }
function gate.remember(reason, remainingMs, now, minMs)
    local span = minMs
    if mathType(remainingMs) == 'integer' and remainingMs > 0 then span = remainingMs end
    return { reason = reason, untilMs = now + span }
end

--- Raison du verdict s'il vaut encore, sinon nil : la bannière est refusée sur place, sans redemander au serveur.
---@param verdict { reason: string, untilMs: integer }|nil
---@param now integer
---@return string|nil
function gate.standing(verdict, now)
    if verdict and now < verdict.untilMs then return verdict.reason end
    return nil
end

--- Débit dépassé à l'ouverture : jamais d'ouverture contre un refus encore valable. `true, 'reuse'` (instantané
--- précédent repris), `true, 'empty'` (ouverte sans données du serveur) ou `false, raison`.
---@param verdict { reason: string, untilMs: integer }|nil
---@param now integer
---@param hasReusable boolean
---@return boolean ok
---@return string modeOrReason
function gate.onRateLimited(verdict, now, hasReusable)
    local reason = gate.standing(verdict, now)
    if reason then return false, reason end
    return true, hasReusable and 'reuse' or 'empty'
end

--- Vrai si ce refus est muet.
---@param reason string
---@return boolean
function gate.muted(reason)
    return MUTED[reason] == true
end

--- Faut-il montrer le message de ce refus ? Jamais deux fois le même en `noticeMs` ; `shown` est tenu à jour.
---@param shown table<string, integer>  raison → moment du dernier message
---@param reason string
---@param now integer
---@param noticeMs integer
---@return boolean
function gate.shouldNotify(shown, reason, now, noticeMs)
    if MUTED[reason] then return false end
    local last = shown[reason]
    if last and now - last < noticeMs then return false end
    shown[reason] = now
    return true
end
