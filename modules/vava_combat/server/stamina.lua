--[[
    vava_combat/server/stamina.lua
    Rôle : l'endurance tenue par le serveur (docs/plan/specs/T-114.md § 5.1, § 7.1 à § 7.7) : une jauge par personnage
           en jeu, en mémoire, jamais sauvegardée (absente = pleine), SANS minuterie ni boucle : le niveau se calcule à
           chaque lecture. Refus `exhausted` en mémoire (avant la réservation d'un geste), préparation au début de la
           vérification (jauge du personnage actif, faim et soif relues par vava_needs:get au plus une fois par
           `needsReadMs`, aucun envoi), prise au dernier pas de la vérification (revérifiée, dépensée sauf pour la
           garde), coup bloqué (dépense, garde brisée, état envoyé au seul défenseur), remise à plein à la mise à terre
           (état envoyé au seul porteur s'il n'était pas plein), oubli, lecture du Conseil. Rien n'est jamais envoyé à
           un autre que le porteur, ni au repos.
    Dépendances : shared/constants.lua, config.lua, shared/endurance.lua, shared/stamina.lua, server/core.lua,
                  bridge/server.lua
]]

local pairs = pairs

local bridge = VavaCombat.bridge
local endurance = VavaCombat.endurance
local cfg = VavaCombat.config
local EVENTS = VavaCombat.EVENTS
local MAX = VavaCombat.ENDURANCE_MAX

local stamina = VavaCombat.stamina
local level = endurance.level

---@class vAvA.StaminaGauge
---@field characterId integer
---@field value integer     dixièmes, vrais à `at`
---@field at integer
---@field restAt integer    la recharge part de max(at, restAt)
---@field rate integer      dixièmes par seconde (faim et soif comprises)
---@field factor number     part de la recharge laissée par les besoins
---@field needsAt integer|nil   dernière lecture de vava_needs (même en échec)
---@field needsKnown boolean    une lecture a réussi

---@type table<integer, vAvA.StaminaGauge>  source → jauge (absente : pleine)
local gauges = {}

---@return integer
local function baseRate()
    return stamina.rateOf(1, cfg)
end

--- Jauge pleine d'un personnage, facteur 1, besoins pas encore lus.
---@param characterId integer|nil
---@param now integer
---@return vAvA.StaminaGauge
local function fresh(characterId, now)
    return { characterId = characterId, value = MAX, at = now, restAt = now, factor = 1, rate = baseRate(),
        needsAt = nil, needsKnown = false }
end

--- Refus en mémoire (ligne 8 bis de swings.use) : `'exhausted', attente` si le coût de la technique dépasse ce qui
--- reste (garde : de quoi bloquer un coup léger), sinon nil. Ne lit aucun export ; une jauge d'un autre personnage que
--- celui en cours (lu au core, seulement avant de refuser) est ignorée : `prepare` tranchera (relecture S-3).
---@param src integer
---@param def table
---@param now integer
---@return string|nil code
---@return integer|nil wait
function stamina.refusal(src, def, now)
    local need = stamina.needOf(def)
    if need <= 0 then return nil end
    local g = gauges[src]
    local wait = stamina.waitFor(g, need, now)
    if not wait or g.characterId ~= bridge.ActiveCharacterId(src) then return nil end
    return 'exhausted', wait
end

--- Début de la vérification d'un geste (phase des exports) : jauge du personnage actif (recréée pleine pour un autre
--- personnage), faim et soif relues au plus une fois par `needsReadMs` (instant noté même en échec) ; une part changée
--- prend effet à `now` (la part déjà rechargée l'a été à l'ancienne pente). Aucun envoi.
---@param src integer
---@param characterId integer
---@param now integer
function stamina.prepare(src, characterId, now)
    local g = gauges[src]
    if not g or g.characterId ~= characterId then
        g = fresh(characterId, now)
        gauges[src] = g
    end
    local rules = cfg.endurance
    if g.needsAt ~= nil and now - g.needsAt < rules.needsReadMs then return end
    g.needsAt = now
    local values = bridge.NeedsValues(src)
    -- l'export a pu céder la main : la jauge a pu être oubliée (rien à faire) ou remplacée entre-temps (coup bloqué) ;
    -- la lecture vaut pour la jauge courante du même personnage (relecture S-2)
    local current = gauges[src]
    if not current or current.characterId ~= characterId then return end
    current.needsAt = now
    local factor = 1
    if values ~= nil then
        factor = stamina.needsFactor(values, rules.needs)
        current.needsKnown = true
    end
    if factor ~= current.factor then
        gauges[src] = stamina.rebase(current, bridge.Timer(), stamina.rateOf(factor, cfg), factor)
    end
end

--- Dernier pas de la vérification, en mémoire, sans rien qui cède la main ensuite : revérifie que le coût est payable
--- (un coup bloqué a pu vider la jauge pendant qu'un crochet cédait la main), puis le dépense (garde : rien, la tenir ne
--- coûte rien). Rend vrai, ou `false, attente`.
---@param src integer
---@param def table
---@param now integer
---@param characterId integer  personnage du geste (jauge absente : créée pleine pour lui)
---@return boolean ok
---@return integer|nil wait
function stamina.take(src, def, now, characterId)
    local need = stamina.needOf(def)
    if need <= 0 then return true end
    local g = gauges[src]
    if not g then
        g = fresh(characterId, now)
        gauges[src] = g
    end
    local wait = stamina.waitFor(g, need, now)
    if wait then return false, wait end
    if def.type == 'blocage' then return true end
    gauges[src] = stamina.spend(g, need, now, cfg)
    return true
end

--- État de la jauge d'un joueur pour sa réponse ou son évènement : dixièmes, ms avant la recharge, dixièmes / s.
---@param src integer
---@param now integer
---@return integer value
---@return integer restIn
---@return integer rate
function stamina.wire(src, now)
    return stamina.wireOf(gauges[src], now, baseRate())
end

--- Coup bloqué (suite au hook vava_health:hit after) : coût selon le coup et ce qui bloque, retiré à la jauge du
--- défenseur ; état envoyé au SEUL défenseur (≈ 32 o). Rend vrai si la garde cède. Jauge absente : créée pleine pour
--- le personnage de la garde (besoins relus au geste suivant). Ne lit jamais vava_needs.
---@param target integer
---@param guardDef table      technique de garde
---@param weight integer
---@param byShield boolean
---@param now integer
---@param characterId integer
---@return boolean broken
function stamina.block(target, guardDef, weight, byShield, now, characterId)
    local cost = stamina.blockCost(guardDef, weight, byShield, cfg)
    if cost <= 0 then return false end
    local g = gauges[target]
    if not g or g.characterId ~= characterId then g = fresh(characterId, now) end
    local drained, broken = stamina.drain(g, cost, now, cfg)
    gauges[target] = drained
    bridge.Send(target, EVENTS.STAMINA, stamina.wireOf(drained, now, baseRate()))
    return broken
end

--- Mise à terre : jauge oubliée (pleine au relevé) ; le porteur reçoit la jauge pleine si elle ne l'était pas.
---@param src integer
function stamina.onDowned(src)
    local g = gauges[src]
    if not g then return end
    gauges[src] = nil
    if level(g, bridge.Timer()) < MAX then bridge.Send(src, EVENTS.STAMINA, MAX, 0, g.rate) end
end

--- Déchargement, départ : jauge oubliée, rien n'est envoyé.
---@param src integer
function stamina.forget(src)
    gauges[src] = nil
end

--- Arrêt du module : tout est oublié.
function stamina.stop()
    gauges = {}
end

--- Lecture du Conseil (/armes voir) et des essais : niveau (dixièmes), pente (dixièmes / s), part laissée par les
--- besoins. Absente : pleine, pente de base, 1.
---@param src integer
---@return { value: integer, rate: integer, factor: number }
function stamina.inspect(src)
    local g = gauges[src]
    if not g then return { value = MAX, rate = baseRate(), factor = 1 } end
    return { value = level(g, bridge.Timer()), rate = g.rate, factor = g.factor }
end

--- Nombre de jauges en mémoire (essais : bornée par le nombre de joueurs).
---@return integer
function stamina.count()
    local count = 0
    for _ in pairs(gauges) do count = count + 1 end
    return count
end
