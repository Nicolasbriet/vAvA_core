--[[
    vava_combat/client/hands.lua
    Rôle : la main du personnage local, vue du client (affichage et demandes : le serveur décide). Arme du royaume en
           main (classe de config_client.lua, jamais un bouclier) et son style ; à la prise en main, geste de dégainer
           et arme « en garde » après `draw.drawMs` ; quand l'arme quitte la main, geste de rengainer et
           `{ sheathing = true }` pendant `draw.sheatheMs` (l'export armed() le rend : la magie reste endormie). Main
           restaurée au chargement du personnage ou au redémarrage du module : en garde d'emblée, sans geste. Gestes du
           style de l'arme chargés à l'avance, ceux du style précédent rendus. Lecture et jeu des gestes (dictionnaire
           chargé avec une attente bornée ; absent : rien n'est joué, une ligne de console par nom et par minute).
           Aucune boucle : tout part du changement de main (bridge/client.lua).
    Dépendances : shared/constants.lua, config_client.lua, shared/techniques.lua, client/core.lua, bridge/client.lua
]]

local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, DoesEntityExist = PlayerPedId, DoesEntityExist
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict, DoesAnimDictExist =
    RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict, DoesAnimDictExist
local TaskPlayAnim, StopAnimTask = TaskPlayAnim, StopAnimTask

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local draw = cfg.draw
local bridge = VavaCombat.bridge
local techniques = VavaCombat.techniques
local SHIELD = VavaCombat.SHIELD_CATEGORY
-- une ligne de console par dictionnaire et par minute au plus
local WARN_MS = 60000
local DICT_POLL_MS = 20

local hands = {}
VavaCombat.hands = hands

---@type { item: string, category: string, family: string, style: string|nil }|nil  arme en main
local weapon = nil
-- instant de la prise en main (nil : en garde)
local drawnAt = nil
---@type { item: string, category: string, family: string, untilMs: integer }|nil  arme rangée, mains pas encore libres
local sheath = nil
-- dictionnaires chargés à l'avance pour le style de l'arme en main
local styleDicts = {}
---@type fun(weapon: table|nil, reason: string)[]
local listeners = {}
-- dictionnaire → instant du dernier avertissement
local warnedAt = {}

---@param key string
---@param fmt string
local function warnLimited(key, fmt, ...)
    local now = GetGameTimer()
    local last = warnedAt[key]
    if last and now - last < WARN_MS then return end
    warnedAt[key] = now
    VavaCombat.log.warn(fmt, ...)
end

--- Classe d'une arme du royaume qui frappe (pas un bouclier), ou nil.
---@param item string|nil
---@return table|nil
local function classOf(item)
    local class = type(item) == 'string' and cfg.weaponClasses[item] or nil
    if type(class) ~= 'table' or class.category == SHIELD then return nil end
    return class
end

-- Gestes --------------------------------------------------------------------------------------------------------------

--- Charge un dictionnaire d'animation, avec une attente bornée (`mode.gestureTimeoutMs`). À appeler dans un thread.
---@param dict string
---@return boolean loaded
function hands.loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then
        warnLimited(dict, "geste : dictionnaire d'animation inconnu '%s'", tostring(dict))
        return false
    end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + cfg.mode.gestureTimeoutMs
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(DICT_POLL_MS) end
    if not HasAnimDictLoaded(dict) then
        warnLimited(dict, "geste : dictionnaire d'animation '%s' non chargé à temps", tostring(dict))
        return false
    end
    return true
end

--- Joue un geste sur son propre ped tout de suite si son dictionnaire est chargé (rend vrai) ; sinon le demande pour
--- la fois suivante et rend faux. OneSync montre le geste aux autres joueurs : rien à envoyer.
---@param gesture { dict: string, clip: string, flag: integer }
---@param durationMs integer|nil  -1 ou nil : longueur du geste
---@return boolean
function hands.playNow(gesture, durationMs)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if not HasAnimDictLoaded(gesture.dict) then
        RequestAnimDict(gesture.dict)
        return false
    end
    TaskPlayAnim(ped, gesture.dict, gesture.clip, 8.0, -8.0, durationMs or -1, gesture.flag, 0.0, false, false, false)
    return true
end

--- Joue un geste, en chargeant son dictionnaire au besoin (thread, attente bornée).
---@param gesture { dict: string, clip: string, flag: integer }
---@param durationMs integer|nil
function hands.play(gesture, durationMs)
    if hands.playNow(gesture, durationMs) then return end
    CreateThread(function()
        if hands.loadDict(gesture.dict) then hands.playNow(gesture, durationMs) end
    end)
end

--- Arrête un geste en cours sur son propre ped.
---@param gesture { dict: string, clip: string }
function hands.stopGesture(gesture)
    local ped = PlayerPedId()
    if ped ~= 0 and DoesEntityExist(ped) then StopAnimTask(ped, gesture.dict, gesture.clip, 2.0) end
end

--- Charge les gestes du style `style` et rend ceux de l'ancien style qui ne servent plus.
---@param style string|nil
local function preload(style)
    local wanted = {}
    if style then
        for _, def in pairs(cfg.techniques) do
            if def.style == style then wanted[def.gesture.dict] = true end
        end
    end
    for dict in pairs(styleDicts) do
        if not wanted[dict] then RemoveAnimDict(dict) end
    end
    styleDicts = wanted
    if next(wanted) == nil then return end
    CreateThread(function()
        for dict in pairs(wanted) do
            if styleDicts[dict] then hands.loadDict(dict) end
        end
    end)
end

-- Main ----------------------------------------------------------------------------------------------------------------

--- Arme tenue : { item, category, family } ; pendant le rengainement : + `sheathing = true` ; sinon nil.
---@return table|nil
function hands.armed()
    if weapon then return { item = weapon.item, category = weapon.category, family = weapon.family } end
    if sheath then
        if GetGameTimer() < sheath.untilMs then
            return { item = sheath.item, category = sheath.category, family = sheath.family, sheathing = true }
        end
        sheath = nil
    end
    return nil
end

--- Arme en main (table du module : à ne pas modifier), ou nil.
---@return table|nil
function hands.weapon()
    return weapon
end

--- Style de l'arme en main (`<famille>_<catégorie>`), ou nil ; il peut n'avoir aucune technique (config.styles).
---@return string|nil
function hands.style()
    return weapon and weapon.style or nil
end

--- Vrai si l'arme en main est en garde (dégainée depuis au moins `draw.drawMs`).
---@param now integer
---@return boolean
function hands.ready(now)
    if not weapon then return false end
    return drawnAt == nil or now - drawnAt >= draw.drawMs
end

--- Prévient `handler(arme|nil, raison)` à chaque changement de main (le mode combat s'endort).
---@param handler fun(weapon: table|nil, reason: string)
function hands.onChange(handler)
    listeners[#listeners + 1] = handler
end

---@param item string|nil
---@param class table
---@return table
local function weaponOf(item, class)
    return { item = item, category = class.category, family = class.family, style = techniques.styleOf(class) }
end

bridge.OnHandChanged(function(_, item, reason)
    local class = classOf(item)
    local now = GetGameTimer()
    if class then
        weapon, sheath = weaponOf(item, class), nil
        if reason == 'changed' then
            drawnAt = now
            hands.play(draw.drawGesture, draw.drawMs)
        else
            drawnAt = nil
        end
    else
        if weapon and reason == 'changed' then
            sheath = { item = weapon.item, category = weapon.category, family = weapon.family,
                untilMs = now + draw.sheatheMs }
            hands.play(draw.sheatheGesture, draw.sheatheMs)
        else
            sheath = nil
        end
        weapon, drawnAt = nil, nil
    end
    preload(weapon and weapon.style or nil)
    for _, listener in ipairs(listeners) do listener(weapon, reason) end
end)

-- ressource (re)démarrée en jeu, l'arme déjà en main : en garde d'emblée
do
    local item = bridge.HandItem()
    local class = classOf(item)
    if class then
        weapon = weaponOf(item, class)
        preload(weapon.style)
    end
end
