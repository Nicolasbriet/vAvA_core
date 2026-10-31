--[[
    vava_magic/client/wheel.lua
    Rôle : roue des sorts. Touche maintenue (Tab par défaut, réglable) : la roue s'ouvre au centre de l'écran, la souris
           choisit (anneau intérieur : les éléments ; extérieur : les sorts connus de l'élément survolé, avec icône,
           niveau, coût, recharge restante) ; relâcher sur un sort le prépare dans les mains, au centre annule, sur
           « Ranger la magie » le retire. Le jeu garde le clavier pour voir la touche relâchée ; la caméra, l'attaque et
           la roue d'armes de GTA sont coupées à chaque image, seulement tant que la roue est ouverte. La page sait
           aussi quelle touche ferme la roue (si le jeu ne voit pas le relâchement). Un sort choisi arme en main
           (vava_combat) : « rangez votre arme » aussitôt.
    Dépendances : shared/, config.lua, client/nui.lua, client/state.lua, client/messages.lua, client/controls.lua,
                  client/keys.lua
]]

local type, ipairs, sort = type, ipairs, table.sort
local CreateThread, Wait, SetTimeout = CreateThread, Wait, SetTimeout
local SetNuiFocus, SetNuiFocusKeepInput, IsNuiFocused, IsPauseMenuActive, SetCursorLocation =
    SetNuiFocus, SetNuiFocusKeepInput, IsNuiFocused, IsPauseMenuActive, SetCursorLocation
local DisableControlAction, HideHudComponentThisFrame = DisableControlAction, HideHudComponentThisFrame

local nui = VavaMagic.nui
local state = VavaMagic.state
local controls = VavaMagic.controls
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local cfg = VavaMagic.config
local CENTER = 0.5
-- contrôles coupés roue ouverte : caméra, attaque, visée, roue d'armes, pause
local BLOCKED = { 1, 2, 24, 25, 37, 140, 141, 142, 257, 263, 264, 14, 15, 16, 17, 199, 200 }
local HUD_WEAPON_WHEEL, HUD_WEAPON_WHEEL_STATS = 19, 20
-- si la page ne répond pas au relâchement, la roue se ferme quand même
local CHOICE_TIMEOUT_MS = 400

local wheel = {}
VavaMagic.wheel = wheel

local open = false
local token = 0

--- Groupes de la roue (ordre de la config) avec les sorts connus de chacun.
---@return table[]
local function groups()
    local byGroup = {}
    for _, name in ipairs(state.knownSpells()) do
        local spellCfg = state.spellConfig(name)
        local element = cfg.elements[spellCfg.element]
        if element then
            local level = state.level(name)
            local list = byGroup[element.group] or {}
            byGroup[element.group] = list
            list[#list + 1] = {
                name = name, label = spellCfg.label, icon = spellCfg.icon, level = level, cost = state.cost(name),
                cooldown = state.cooldownLeft(name), color = element.color, order = spellCfg.order or 1000,
            }
        end
    end
    local result = {}
    for _, group in ipairs(cfg.wheel.groups) do
        local list = byGroup[group.id]
        if list then
            sort(list, function(a, b) return a.order < b.order end)
            result[#result + 1] = { id = group.id, label = group.label, icon = group.icon, spells = list }
        end
    end
    return result
end

local function close()
    if not open then return end
    open = false
    nui.send('wheel:close')
    SetNuiFocusKeepInput(false)
    -- une fenêtre ouverte entre-temps (sigil tendu…) garde la main
    if not nui.modal() then SetNuiFocus(false, false) end
end

local function onDown()
    if open or not state.isMage() or nui.modal() or IsNuiFocused() or IsPauseMenuActive() then return end
    local list = groups()
    if #list == 0 then return end
    open = true
    token = token + 1
    nui.send('wheel:open', { groups = list, selected = state.selected() or '', releaseKey = keys.label('roue') })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SetCursorLocation(CENTER, CENTER)
    CreateThread(function()
        -- boucle par image justifiée : seulement roue ouverte
        while open do
            for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end
            HideHudComponentThisFrame(HUD_WEAPON_WHEEL)
            HideHudComponentThisFrame(HUD_WEAPON_WHEEL_STATS)
            Wait(0)
        end
    end)
end

local function onUp()
    if not open then return end
    local mine = token
    nui.send('wheel:release')
    SetTimeout(CHOICE_TIMEOUT_MS, function()
        if open and token == mine then close() end
    end)
end

-- choix de la page : { spell } ou { deselect = true } ; rien = annuler
nui.on('wheel:choose', function(data)
    close()
    if data.deselect == true then
        controls.select(nil)
    elseif type(data.spell) == 'string' and data.spell ~= '' then
        -- le sort est prêt, mais l'arme en main l'empêchera de partir : on le dit tout de suite
        if controls.select(data.spell) and controls.armed() then messages.refuse('armed') end
    end
    return { ok = true }
end)

---@return boolean
function wheel.isOpen()
    return open
end

--- Retour à la sélection du personnage, arrêt du module.
function wheel.close()
    close()
end

keys.bindHold('roue', onDown, onUp)
