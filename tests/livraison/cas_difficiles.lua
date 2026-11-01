--[[
    tests/livraison/cas_difficiles.lua
    Rôle : Lua 5.4 valide truffé de pièges pour l'allègement du Lua livré (T-154) : allégé par
           `node scripts/livraison.js --essai` et prouvé par scripts/lib/meme-code.lua à chaque vérification
           (string.dump, numéros de ligne compris). Ne fait rien : rend une table de ses valeurs.
           Jamais chargé en jeu, ni linté, ni audité (tests/). Ne pas « nettoyer » : chaque bizarrerie est voulue.
    Dépendances : aucune.
]]

local t = {}
local a, b = 3, 4

-- chaînes qui contiennent de quoi tromper un lecteur naïf
t.s3 = "a -- b" -- c
t.s4 = '--[[ pas un commentaire ]]'
t.s5 = [[ -- dedans
]] -- dehors
t.s6 = [==[ ]] ]=] ]==] t.x6 = 1
--[==[ ]] ]=] ]==]t.x7 = 1
t.x8 = a--[[c]]or b
t.s9 = "\\" -- c
t.s10 = 'l\'a -- ici' -- c
t.s11 = "a\z
   -- dans la chaîne"
t.s12 = "a\
-- dans la chaîne"
t.x13 = 1 ---[[ court
t.y13 = 2
--]]
--[ court
--[=x court
t.x19 = 1--2
t.y19 = 0x1p-4 -- c
t.z19 = 1e-5--c
		t.x21 = 1 -- c (indentation par tabulations gardée)
t.x22 = a - b -- c
t.y22 = a - -b
--[=[ ]] ]=]t.x24 = 1
t.x25 = 1 --[[ x ]] + 2

-- chaîne longue dont une ligne finit par des blancs (ils restent : ils sont dans la chaîne)
t.blancs = [[ligne avec blancs   
fin]]

-- clé et index en chaîne longue, longueur d'une chaîne qui ressemble à un commentaire
t[ [[clé]] ] = #"--"
t.lu = t[ [[clé]] ]

--[==[ bloc de commentaire
sur plusieurs lignes, ]] et ]=] dedans
]==] t.apres = 'code sur la dernière ligne du bloc'

-- étiquette, goto, attributs, division entière
do
    local n <const> = 7 // 2
    local i = 0
    ::suite::
    i = i + 1
    if i < n then goto suite end
    t.boucle = i
end

local function plusieurs(x,
    y) -- arguments sur deux lignes
    local z = x * y --[[ produit ]]
    return z --[[ un commentaire long
    juste avant la fin ]] end
t.f = plusieurs(a, b)

local s = 'x'--[[collé]]..'y'
t.s = s
t.moins = 5--[[un]]-2
t.egal = (1 ==--[[ entre ]]1)

return t
