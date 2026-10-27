--[[
    vava_magic/client/state.lua
    Rôle : ce que le client sait de sa magie, pour afficher et pré-vérifier (le serveur décide de tout) : vue de la
           fiche (mage, sorts et leur XP), mana prédite d'après le dernier envoi du serveur (même rythme de
           régénération), temps de recharge appris aux fins d'incantation, sorts d'autres modules.
    Dépendances : shared/, config.lua
]]

local type, ipairs, pairs, floor, min = type, ipairs, pairs, math.floor, math.min
local GetGameTimer = GetGameTimer

local cfg = VavaMagic.config
local progression = VavaMagic.progression

local state = {}
VavaMagic.state = state

local view = nil
---@type table<string, integer>  sort → XP
local known = {}
---@type table<string, table>  config des sorts d'autres modules
local catalog = {}
---@type table<string, integer>  sort → fin du temps de recharge (horloge locale)
local cooldowns = {}
local admin = false
-- mana : valeur au moment `base`, rythme de régénération
local pool = nil
local listeners = {}

---@param fn fun()  appelée à chaque changement de la fiche ou de la mana
function state.onChange(fn)
    listeners[#listeners + 1] = fn
end

local function changed()
    for _, fn in ipairs(listeners) do fn() end
end

--- Nouvelle vue de la fiche (à l'apparition ou après un changement).
---@param newView table
---@param newCatalog? table
function state.set(newView, newCatalog)
    if type(newView) ~= 'table' then return end
    view = newView
    known = {}
    for _, spell in ipairs(type(newView.spells) == 'table' and newView.spells or {}) do
        if type(spell) == 'table' and type(spell.name) == 'string' and type(spell.xp) == 'number' then known[spell.name] = spell.xp end
    end
    if type(newCatalog) == 'table' then catalog = newCatalog end
    changed()
end

---@param value boolean
function state.setAdmin(value)
    admin = value == true
end

---@return boolean
function state.isAdmin()
    return admin
end

--- Départ du personnage : tout est oublié.
function state.clear()
    view, known, cooldowns, pool, admin = nil, {}, {}, nil, false
    changed()
end

---@return boolean
function state.ready()
    return view ~= nil
end

---@return boolean
function state.isMage()
    return view ~= nil and view.isMage == true
end

---@return table|nil
function state.view()
    return view
end

--- Config d'un sort (fichier config.lua, ou envoyée par le serveur pour les sorts d'autres modules).
---@param name string
---@return table|nil
function state.spellConfig(name)
    return cfg.spells[name] or catalog[name]
end

--- Noms des sorts connus, dans l'ordre du grimoire.
---@return string[]
function state.knownSpells()
    local names = {}
    for name in pairs(known) do
        if state.spellConfig(name) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        local oa, ob = state.spellConfig(a).order or 1000, state.spellConfig(b).order or 1000
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return names
end

---@param name string
---@return integer|nil
function state.xp(name)
    return known[name]
end

---@param name string
---@return integer|nil
function state.level(name)
    local xp = known[name]
    return xp and progression.levelOf(xp) or nil
end

---@param name string
---@param share? number
---@return integer|nil
function state.cost(name, share)
    local spellCfg, level = state.spellConfig(name), state.level(name)
    if not spellCfg or not level then return nil end
    return progression.cost(spellCfg, level, share)
end

-- Mana -------------------------------------------------------------------------------------------------------------

--- Mana envoyée par le serveur : valeur, maximum, points et période de régénération, temps écoulé dans la période.
function state.setMana(value, max, points, period, elapsed)
    pool = { value = value, max = max, points = points, period = period, base = GetGameTimer() - elapsed }
    changed()
end

--- Mana prédite maintenant (0 sans mana).
---@return integer value
---@return integer max
function state.mana()
    if not pool then return 0, cfg.mana.max end
    if pool.value >= pool.max then return pool.max, pool.max end
    local periods = floor((GetGameTimer() - pool.base) / pool.period)
    return min(pool.max, pool.value + periods * pool.points), pool.max
end

-- Temps de recharge ------------------------------------------------------------------------------------------------

---@param name string
---@param ms integer
function state.setCooldown(name, ms)
    cooldowns[name] = GetGameTimer() + ms
end

---@param name string
---@return integer  millisecondes restantes
function state.cooldownLeft(name)
    local untilMs = cooldowns[name]
    if not untilMs then return 0 end
    local left = untilMs - GetGameTimer()
    return left > 0 and left or 0
end
