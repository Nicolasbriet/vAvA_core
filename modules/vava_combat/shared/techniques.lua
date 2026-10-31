--[[
    vava_combat/shared/techniques.lua
    Rôle : règles pures des techniques, côté client et serveur (docs/plan/specs/T-112.md § 7.2) : style d'une arme
           (famille et catégorie), cycle d'un coup (préparation, frappe, récupération), admission d'une demande par le
           serveur (enchaînement pendant la récupération, délai, nombre de coups enchaînés), et choix de la technique
           d'une touche par le client (prédiction : le serveur décide). Aucune native, aucun état.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local max = math.max

local techniques = {}
VavaCombat.techniques = techniques

--- Style d'une arme : `<famille>_<catégorie>` de sa classe (config.weaponClasses), ou nil.
---@param class any
---@return string|nil
function techniques.styleOf(class)
    if type(class) ~= 'table' or type(class.family) ~= 'string' or type(class.category) ~= 'string' then return nil end
    return class.family .. '_' .. class.category
end

--- Cycle d'un coup qui part à `now` : ouverture et fin de la frappe, fin de la récupération (ms).
---@param def table  technique ({ phases = { windup, active, recovery } })
---@param now integer
---@return { startedAt: integer, openAt: integer, closeAt: integer, endAt: integer }
function techniques.plan(def, now)
    local p = def.phases
    local openAt = now + p.windup
    local closeAt = openAt + p.active
    return { startedAt = now, openAt = openAt, closeAt = closeAt, endAt = closeAt + p.recovery }
end

---@param list any
---@param id string
---@return boolean
local function contains(list, id)
    if type(list) ~= 'table' then return false end
    for _, value in ipairs(list) do
        if value == id then return true end
    end
    return false
end

--- Admission d'une demande par le serveur. `prev` : dernier coup ({ def, closeAt, endAt, chainCount }) ou nil ; `rules`
--- = { earlyMs, chainMax, styles }. Libre (aucun coup, ou fin de récupération à `earlyMs` près) : seule la technique qui
--- ouvre sa touche est admise (`not_opener`). Pendant la récupération (frappe finie, à `earlyMs` près), une technique de
--- `prev.def.chain` est admise si elle ne dépasse pas `chainMax` coups enchaînés (`chain_limit`). Sinon `busy`. Rend
--- `true, chainCount` ou `false, code[, attente en ms]`.
---@param prev table|nil
---@param def table
---@param id string
---@param now integer
---@param rules { earlyMs: integer, chainMax: integer, styles: table }
---@return boolean ok
---@return integer|string chainCount_or_code
---@return integer|nil wait
function techniques.admit(prev, def, id, now, rules)
    local early = rules.earlyMs
    if not prev or now >= prev.endAt - early then
        local style = rules.styles[def.style]
        local keys = type(style) == 'table' and style.keys
        if type(keys) ~= 'table' or keys[def.type] ~= id then return false, 'not_opener' end
        return true, 0
    end
    local chained = contains(prev.def and prev.def.chain, id)
    if chained and now >= prev.closeAt - early then
        local count = (prev.chainCount or 0) + 1
        if count > rules.chainMax then return false, 'chain_limit', max(0, prev.endAt - early - now) end
        return true, count
    end
    return false, 'busy', max(0, (chained and prev.closeAt or prev.endAt) - early - now)
end

--- Technique à jouer à l'appui d'une touche (`slot` : legere, lourde), côté client : libre, celle qui ouvre la touche ;
--- pendant la récupération du coup en cours, la première de sa chaîne qui est du type de la touche ; sinon rien, et
--- l'attente avant qu'elle soit permise (fin de la frappe si la chaîne en a une de ce type, sinon fin du coup).
---@param styleDef table|nil   style de l'arme tenue (config.styles[...])
---@param slot string
---@param prev table|nil       coup en cours ({ closeAt, endAt })
---@param prevDef table|nil    sa technique
---@param now integer
---@param all table            toutes les techniques (config.techniques)
---@return string|nil id
---@return integer|nil wait
function techniques.pick(styleDef, slot, prev, prevDef, now, all)
    local keys = type(styleDef) == 'table' and styleDef.keys
    if type(keys) ~= 'table' then return nil, nil end
    if not prev or now >= prev.endAt then return keys[slot], nil end
    local follow = nil
    if type(prevDef) == 'table' and type(prevDef.chain) == 'table' then
        for _, id in ipairs(prevDef.chain) do
            local def = all[id]
            if type(def) == 'table' and def.type == slot then
                follow = id
                break
            end
        end
    end
    if follow then
        if now >= prev.closeAt then return follow, nil end
        return nil, prev.closeAt - now
    end
    return nil, prev.endAt - now
end
