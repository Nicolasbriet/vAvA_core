--[[
    vava_voice/client/range.lua
    Rôle : portée de la voix du joueur. La portée choisie (touche) est gardée sur sa machine. Une limite décidée par
           le serveur (à terre…) borne la portée : la touche ne fait alors tourner que les portées permises, sans
           oublier le choix d'avant, qui revient à la levée de la limite. L'effet de la zone de voix où se trouve le
           joueur multiplie la distance. Chaque changement règle Mumble et le médaillon ; le cercle au sol n'apparaît
           qu'à l'appui sur la touche, et seulement si le joueur ne l'a pas retiré dans la bannière (1.4.0).
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/hud.lua, client/mumble.lua,
                  client/ring.lua
]]

local mathType, min = math.type, math.min
local GetResourceKvpInt, SetResourceKvpInt = GetResourceKvpInt, SetResourceKvpInt

local cfg = VavaVoice.config
local hud, mumble, ring = VavaVoice.hud, VavaVoice.mumble, VavaVoice.ring
local RANGES = cfg.ranges
local COUNT = #RANGES
local NO_LIMIT = VavaVoice.NO_LIMIT
local HOOK_CHANGED = VavaVoice.HOOKS.RANGE_CHANGED
local KVP = cfg.client.rangeKvp

local range = {}
VavaVoice.range = range

---@param index any
---@return boolean
local function isIndex(index)
    return mathType(index) == 'integer' and index >= 1 and index <= COUNT
end

-- choix du joueur (gardé), choix pendant une limite (oublié à sa levée), limite, effet de la zone
local saved = GetResourceKvpInt(KVP)
local preferred = isIndex(saved) and saved or cfg.defaultRange
local temporary = nil
local cap = NO_LIMIT
local multiplier = 1.0
-- réglage du joueur dans la bannière du royaume (1.4.0) : cercle au sol au changement de portée
local ringEnabled = true

--- Montre ou non le cercle au sol au changement de portée (réglage `voice.circle` de vava_pause).
---@param enabled boolean
function range.setRing(enabled)
    ringEnabled = enabled ~= false
end

---@return integer
function range.index()
    if cap == NO_LIMIT then return preferred end
    return min(temporary or preferred, cap)
end

---@return number
function range.distance()
    return RANGES[range.index()].distance * multiplier
end

--- Règle Mumble et le médaillon sur la portée du moment ; `withRing` : montre le cercle au sol.
---@param withRing? boolean
function range.apply(withRing)
    local index = range.index()
    local distance = range.distance()
    mumble.setDistance(distance)
    hud.set(index / COUNT)
    if withRing and ringEnabled then ring.show(distance) end
    VavaVoice.core.hooks.runAfter(HOOK_CHANGED, { index = index, name = RANGES[index].name, distance = distance })
end

--- Touche : portée suivante (parmi celles permises), puis retour à la première.
function range.cycle()
    if cap == NO_LIMIT then
        preferred = preferred % COUNT + 1
        SetResourceKvpInt(KVP, preferred)
    else
        temporary = range.index() % cap + 1
    end
    range.apply(true)
end

--- Limite reçue du serveur : numéro de la plus haute portée permise, NO_LIMIT pour aucune.
---@param value any
function range.setCap(value)
    if mathType(value) ~= 'integer' or (value ~= NO_LIMIT and not isIndex(value)) then return end
    if value == cap then return end
    cap = value
    if cap == NO_LIMIT then temporary = nil end
    range.apply(false)
end

--- Effet de la zone de voix où se trouve le joueur.
---@param value number
function range.setMultiplier(value)
    if value == multiplier then return end
    multiplier = value
    range.apply(false)
end

--- Portée du moment : { index, name, label, distance }.
---@return table
function range.current()
    local index = range.index()
    return { index = index, name = RANGES[index].name, label = RANGES[index].label, distance = range.distance() }
end
