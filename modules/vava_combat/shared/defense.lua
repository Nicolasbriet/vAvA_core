--[[
    vava_combat/shared/defense.lua
    Rôle : règles pures de la défense, servies au seul serveur (docs/plan/specs/T-113.md § 7.2) : fenêtre ouverte d'un
           geste défensif, garde abaissée (tenue minimale, récupération), adversaire de face, étiquettes évitées,
           bloquées ou parées, part bloquée (bouclier encore accroché, sinon l'arme ; émoussée : × dullFactor), délais
           d'une parade ratée et entre deux pas de côté, poids d'un coup bloqué (son coût d'endurance : shared/stamina.lua,
           T-114). Aucune native, aucun état ; une valeur non finie rend faux ou nil, jamais une erreur.
           Complète VavaCombat.defense (server/defense.lua y ajoute la part qui tient la mémoire).
    Dépendances : shared/constants.lua, shared/geometry.lua
]]

local type, ipairs = type, ipairs
local floor, huge, max, min = math.floor, math.huge, math.max, math.min

local geometry = VavaCombat.geometry

local defense = {}
VavaCombat.defense = defense

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Vrai si `swing` est une garde ouverte : un blocage pas encore abaissé (closeAt absent).
---@param swing any
---@return boolean
local function openGuard(swing)
    return type(swing) == 'table' and type(swing.def) == 'table' and swing.def.type == 'blocage' and swing.closeAt == nil
end
defense.openGuard = openGuard

--- Vrai si le geste défensif `swing` protège à `now` : accepté (ni réservé, ni refusé, ni annulé) ; parade, esquive :
--- `openAt ≤ now ≤ closeAt` ; garde : `openAt ≤ now` et (ouverte, ou `now ≤ closeAt`).
---@param swing any
---@param now any
---@return boolean
function defense.open(swing, now)
    if type(swing) ~= 'table' or swing.pending or swing.refused or swing.cancelled or not finite(now) then return false end
    if not finite(swing.openAt) or now < swing.openAt then return false end
    if swing.closeAt == nil then return openGuard(swing) end
    return finite(swing.closeAt) and now <= swing.closeAt
end

--- Abaisse une garde ouverte : `closeAt = max(now, openAt + active)` (tenue minimale), `endAt = closeAt + recovery`.
--- Rend vrai si elle a fermé ; rien sinon.
---@param swing any
---@param now integer
---@return boolean
function defense.close(swing, now)
    if not openGuard(swing) or not finite(now) then return false end
    local p = swing.def.phases
    swing.closeAt = max(now, swing.openAt + p.active)
    swing.endAt = swing.closeAt + p.recovery
    return true
end

--- Vrai si l'attaquant est de face : au contact (sous `geometry.closeRange`) ou dans l'arc protégé (ouverture totale
--- `angleDeg`, tolérance d'angle ajoutée au demi-angle) ; écart de hauteur au plus `maxHeight` + tolérance.
---@param defPos table      position du défenseur
---@param defHeading number cap du défenseur
---@param atkPos table      position de l'attaquant
---@param angleDeg number
---@param cfg table         config (geometry, tolerance)
---@return boolean
function defense.frontal(defPos, defHeading, atkPos, angleDeg, cfg)
    if not finite(angleDeg) then return false end
    local distance, height = geometry.flat(defPos, atkPos)
    if not distance then return false end
    local g, tol = cfg.geometry, cfg.tolerance
    if height > g.maxHeight + tol.height then return false end
    if distance < g.closeRange then return true end
    local angle = geometry.flatAngle(geometry.forward(defHeading), defPos, atkPos)
    if not angle then return false end
    return angle <= angleDeg / 2 + tol.angle
end

--- Vrai si une étiquette de `any` est posée et aucune de `never`.
---@param tags any        map étiquette → true
---@param any string[]
---@param never string[]
---@return boolean
function defense.tagsMatch(tags, any, never)
    if type(tags) ~= 'table' then return false end
    for _, tag in ipairs(never) do
        if tags[tag] then return false end
    end
    for _, tag in ipairs(any) do
        if tags[tag] then return true end
    end
    return false
end

--- Part bloquée : bouclier du cache encore accroché (même numéro de pile) → `shieldBlock`, sinon `weaponBlock` ;
--- émoussé : × `wearCfg.dullFactor`. Rend la part et `'shield'` ou `'weapon'`.
---@param guard table  cache de la garde { weaponBlock, weaponDull, shieldInstanceId?, shieldBlock?, shieldDull? }
---@param hungInstanceId integer|nil  pile du bouclier accroché en ce moment
---@param wearCfg table
---@return number factor
---@return string by
function defense.blockFactor(guard, hungInstanceId, wearCfg)
    if guard.shieldInstanceId ~= nil and hungInstanceId == guard.shieldInstanceId and finite(guard.shieldBlock) then
        return guard.shieldDull and guard.shieldBlock * wearCfg.dullFactor or guard.shieldBlock, 'shield'
    end
    local block = finite(guard.weaponBlock) and guard.weaponBlock or 0
    return guard.weaponDull and block * wearCfg.dullFactor or block, 'weapon'
end

--- Montant bloqué : `min(amount, amount × factor)` arrondi au dixième ; 0 pour une valeur illisible.
---@param amount any
---@param factor any
---@return number
function defense.blockedAmount(amount, factor)
    if not finite(amount) or not finite(factor) or amount <= 0 or factor <= 0 then return 0 end
    return min(amount, floor(amount * factor * 10 + 0.5) / 10)
end

--- Attente avant une autre parade : nil si aucune parade ou si elle a paré ; sinon `closeAt + missCooldownMs − now`
--- (nil si ≤ 0). Une parade annulée compte comme ratée.
---@param last table|nil  dernière parade acceptée
---@param now integer
---@param cfg table
---@return integer|nil
function defense.parryWait(last, now, cfg)
    if type(last) ~= 'table' or last.parried or not finite(last.closeAt) or not finite(now) then return nil end
    local wait = last.closeAt + cfg.defense.parry.missCooldownMs - now
    return wait > 0 and wait or nil
end

--- Attente avant un autre pas de côté (départ du dernier + `dodgeCooldownMs`), ou nil.
---@param lastStart integer|nil
---@param now integer
---@param cfg table
---@return integer|nil
function defense.dodgeWait(lastStart, now, cfg)
    if not finite(lastStart) or not finite(now) then return nil end
    local wait = lastStart + cfg.defense.dodgeCooldownMs - now
    return wait > 0 and wait or nil
end

--- Poids d'un coup bloqué : `endurance.block.heavyWeight` pour une technique `lourde`, sinon 1 (technique inconnue : 1).
---@param def table|nil
---@param cfg table
---@return integer
function defense.weightOf(def, cfg)
    if type(def) == 'table' and def.type == 'lourde' then return cfg.endurance.block.heavyWeight end
    return 1
end
