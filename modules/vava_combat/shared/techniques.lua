--[[
    vava_combat/shared/techniques.lua
    Rôle : règles pures des techniques lues par le client et le serveur : style d'une arme, cycle d'un coup, technique
           d'une touche (prédiction du client). L'admission, du seul serveur, est dans shared/admission.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs

local techniques = {}
VavaCombat.techniques = techniques

--- Style d'une arme : `<famille>_<catégorie>` de sa classe (config.weaponClasses), ou nil.
function techniques.styleOf(class)
    if type(class) ~= 'table' or type(class.family) ~= 'string' or type(class.category) ~= 'string' then return nil end
    return class.family .. '_' .. class.category
end

--- Cycle d'un coup parti à `now` : { startedAt, openAt, closeAt, endAt } (ms). Garde (`blocage`) : ouverte, sans
--- closeAt ni endAt (posés quand on l'abaisse).
function techniques.plan(def, now)
    local p = def.phases
    local openAt = now + p.windup
    if def.type == 'blocage' then return { startedAt = now, openAt = openAt } end
    local closeAt = openAt + p.active
    return { startedAt = now, openAt = openAt, closeAt = closeAt, endAt = closeAt + p.recovery }
end

--- Technique d'une touche (`slot`) côté client : libre, celle qui ouvre ; pendant la récupération, la première de la
--- chaîne du type de la touche ; sinon `nil, attente` (fin de frappe si la chaîne en a une, sinon fin du coup) ; garde
--- ouverte : rien.
function techniques.pick(styleDef, slot, prev, prevDef, now, all)
    local keys = type(styleDef) == 'table' and styleDef.keys
    if type(keys) ~= 'table' or (prev and not prev.endAt) then return nil, nil end
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
