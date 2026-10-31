--[[
    vava_magic/shared/hands.lua
    Rôle : règles pures des mains prises, vues du joueur (T-149 : la magie et le mode combat). Ce que tient le
           personnage est l'un de :
             - `native`    : arme de GTA sortie ;
             - `weapon`    : arme du royaume en main (`vava_combat:armed()`, sans `sheathing`) : le mode combat de
                             vava_combat a les mêmes boutons que la magie ;
             - `sheathing` : arme du royaume qu'on rengaine encore (`armed()` rend `sheathing = true`, 1,5 s) ;
             - nil         : mains libres (outil, bouclier, rien).
           Arme du royaume en main : les touches de la souris sont au combat, la magie se tait (aucun rappel « rangez
           votre arme ») et ne verrouille personne (un seul anneau, celui du combat). Pendant le rengainement : un mot
           propre (« vous rengainez »), jamais le refus brut. Arme de GTA : le rappel d'avant. La roue et `/lancer`
           (gestes de magie explicites) disent toujours pourquoi le sort ne part pas. Affichage seulement : le serveur
           refuse lui-même (`armed`, `sheathing`, `shielded`).
    Dépendances : shared/constants.lua
]]

local hands = {}
VavaMagic.hands = hands

hands.NATIVE = 'native'
hands.WEAPON = 'weapon'
hands.SHEATHING = 'sheathing'

--- Code de refus (texte de `texts.errors`) pour des mains prises : `sheathing` pendant le rengainement, sinon `armed`.
---@param held string  hands.NATIVE, hands.WEAPON ou hands.SHEATHING
---@return string
function hands.code(held)
    if held == hands.SHEATHING then return 'sheathing' end
    return 'armed'
end

--- Que dire quand un geste de magie trouve les mains prises ? Rend le code à montrer, ou nil (se taire).
---   - mains libres : rien ;
---   - geste explicite (roue, `/lancer`) : toujours dit (`armed` ou `sheathing`) ;
---   - touche de la souris, arme du royaume en main (mode combat) : rien, la touche est au combat ;
---   - touche, arme de GTA ou rengainement : une fois par arme sortie (`noticed` : déjà dit pour elle), jamais deux
---     fois en moins de `minMs`.
---@param held string|nil      ce que tiennent les mains (hands.NATIVE, WEAPON, SHEATHING) ou nil
---@param explicit boolean     roue ou commande
---@param noticed boolean      déjà dit pour l'arme sortie
---@param lastAt integer|nil   instant du dernier mot (GetGameTimer), nil si jamais
---@param now integer
---@param minMs integer        `controls.armedNoticeMs`
---@return string|nil code
function hands.notice(held, explicit, noticed, lastAt, now, minMs)
    if held == nil then return nil end
    if explicit then return hands.code(held) end
    if held == hands.WEAPON then return nil end
    if noticed then return nil end
    if lastAt and now - lastAt < minMs then return nil end
    return hands.code(held)
end

--- Le verrou de la magie peut-il servir ? Non quand une arme du royaume est en main ou qu'on la rengaine : le
--- verrou est alors celui du combat (même bouton), la magie n'ajoute pas son anneau.
---@param held string|nil
---@return boolean
function hands.canLock(held)
    return held ~= hands.WEAPON and held ~= hands.SHEATHING
end
