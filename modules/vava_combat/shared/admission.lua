--[[
    vava_combat/shared/admission.lua
    Rôle : admission d'une demande de technique par le serveur, règle pure servie au seul serveur
           (docs/plan/specs/T-112.md § 7.2) : enchaînement pendant la récupération, délai, nombre de coups enchaînés.
           Complète VavaCombat.techniques (shared/techniques.lua, partagé avec le client, qui n'en a pas besoin).
    Dépendances : shared/constants.lua, shared/techniques.lua
]]

local type, ipairs = type, ipairs
local max = math.max

local techniques = VavaCombat.techniques

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
