--[[
    vava_magic/shared/hands.lua
    Rôle : règles pures des mains prises (arme de GTA, arme du royaume, rengainement) : ce que la magie dit aux touches
           et si elle verrouille. Affichage seulement ; détail : README, « La magie et le mode combat ».
    Dépendances : shared/constants.lua
]]

local hands = {}
VavaMagic.hands = hands

hands.NATIVE = 'native'
hands.WEAPON = 'weapon'
hands.SHEATHING = 'sheathing'

---@param held string
---@return string
function hands.code(held)
    if held == hands.SHEATHING then return 'sheathing' end
    return 'armed'
end

--- Code à montrer (ou nil) : geste explicite toujours dit ; touche : rien arme du royaume en main, sinon une fois par
--- arme et jamais deux fois en moins de `minMs`.
function hands.notice(held, explicit, noticed, lastAt, now, minMs)
    if held == nil then return nil end
    if explicit then return hands.code(held) end
    if held == hands.WEAPON then return nil end
    if noticed then return nil end
    if lastAt and now - lastAt < minMs then return nil end
    return hands.code(held)
end

---@param held string|nil
---@return boolean
function hands.canLock(held)
    return held ~= hands.WEAPON and held ~= hands.SHEATHING
end
