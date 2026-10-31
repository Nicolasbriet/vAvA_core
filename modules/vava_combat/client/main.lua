--[[
    vava_combat/client/main.lua
    Rôle : assemblage côté joueur : notification du serveur (seuils d'usure, coup retenu, réponse de /armes sans
           vava_chat) affichée par vava_hud sinon par le jeu ; exports client `armed()` (arme tenue par le personnage
           local, ou rangée depuis moins de `draw.sheatheMs` : règle « mains vides » de la magie), `inCombatMode()`
           (mode combat éveillé et actif) et `shieldHung()` (bouclier accroché sur son propre ped) ; démarrage des
           contrôles natifs et du suivi des boucliers. Aucune NUI.
    Dépendances : shared/constants.lua, config_client.lua, shared/shield.lua, client/core.lua, bridge/client.lua,
                  client/natives.lua, client/shields.lua, client/hands.lua, client/mode.lua
]]

local type = type
local sub = string.sub
local RegisterNetEvent, PlayerPedId, DoesEntityExist, Entity = RegisterNetEvent, PlayerPedId, DoesEntityExist, Entity

local core = VavaCombat.core
if not core then return end

local bridge = VavaCombat.bridge
local shield = VavaCombat.shield
local hands = VavaCombat.hands
local mode = VavaCombat.mode
local EVENTS = VavaCombat.EVENTS
local SHIELD_STATE = VavaCombat.SHIELD_STATE
local MAX_NOTIFICATION = VavaCombat.MAX_NOTIFICATION

-- seuil d'usure, coup retenu ou réponse du Conseil : texte borné, nature parmi celles du HUD (bridge)
RegisterNetEvent(EVENTS.NOTIFY, function(text, kind)
    if type(text) ~= 'string' or text == '' then return end
    bridge.Notify(sub(text, 1, MAX_NOTIFICATION), type(kind) == 'string' and kind or 'info')
end)

--- Arme tenue par le personnage local : { item, category, family } ; rangée depuis moins de `draw.sheatheMs` : +
--- `sheathing = true` (les mains ne sont pas encore libres) ; sinon nil (mains vides, outil, bouclier). Lu dans le
--- cache de la main (aucune lecture du personnage) : sert à l'affichage et aux demandes, jamais à décider.
exports('armed', function()
    return hands.armed()
end)

--- Mode combat éveillé et actif (pour la magie, T-149, et le HUD de l'endurance, T-114).
exports('inCombatMode', function()
    return mode.isActive()
end)

--- Bouclier accroché sur son propre ped (nom de l'objet), ou nil.
exports('shieldHung', function()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local value = Entity(ped).state[SHIELD_STATE]
    if value == nil or not shield.valid(value) then return nil end
    return value.item
end)

VavaCombat.natives.start()
VavaCombat.shields.start()
