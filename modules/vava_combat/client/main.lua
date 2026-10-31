--[[
    vava_combat/client/main.lua
    Rôle : assemblage côté joueur : notification du serveur (seuils d'usure, réponse de /armes sans vava_chat) affichée
           par vava_hud sinon par le jeu ; exports client `armed()` (arme tenue par le personnage local, pour la règle
           « mains vides » de la magie et le mode combat de T-112) et `shieldHung()` (bouclier accroché sur son propre
           ped) ; démarrage des contrôles natifs et du suivi des boucliers. Aucune NUI, aucun RPC.
    Dépendances : shared/constants.lua, config_client.lua, shared/shield.lua, client/core.lua, bridge/client.lua,
                  client/natives.lua, client/shields.lua
]]

local type = type
local sub = string.sub
local RegisterNetEvent, PlayerPedId, DoesEntityExist, Entity = RegisterNetEvent, PlayerPedId, DoesEntityExist, Entity

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local bridge = VavaCombat.bridge
local shield = VavaCombat.shield
local EVENTS = VavaCombat.EVENTS
local SHIELD = VavaCombat.SHIELD_CATEGORY
local SHIELD_STATE = VavaCombat.SHIELD_STATE
local MAX_NOTIFICATION = VavaCombat.MAX_NOTIFICATION

-- seuil d'usure ou réponse du Conseil : texte borné, nature parmi celles du HUD (bridge)
RegisterNetEvent(EVENTS.NOTIFY, function(text, kind)
    if type(text) ~= 'string' or text == '' then return end
    bridge.Notify(sub(text, 1, MAX_NOTIFICATION), type(kind) == 'string' and kind or 'info')
end)

--- Arme tenue par le personnage local : { item, category, family }, ou nil (mains vides, outil, bouclier). Lu dans le
--- champ de l'inventaire (envoyé par le serveur au seul joueur) : sert à l'affichage et aux demandes, jamais à décider.
exports('armed', function()
    local item = bridge.HandItem()
    local def = item and cfg.weapons[item]
    if type(def) ~= 'table' or def.category == SHIELD then return nil end
    return { item = item, category = def.category, family = def.family }
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
