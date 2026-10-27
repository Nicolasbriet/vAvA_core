--[[
    vava_magic/client/spells/lueur.lua
    Rôle : sort Lueur côté client : la même touche allume (incantation) ou éteint sa lumière ; une autre ancre un
           orbe là où l'on regarde (niveau 4, position revérifiée par le serveur) ; couleur au niveau 5 (grimoire ou
           /lueur couleur). Le rendu de toutes les lumières est dans client/ambient.lua.
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local ipairs, lower = ipairs, string.lower
local concat = table.concat
local CreateThread, PlayerPedId, Entity = CreateThread, PlayerPedId, Entity

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local casting = VavaMagic.casting
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local aim = VavaMagic.aim
local cfg = VavaMagic.config
local spellCfg = cfg.spells.lueur
local anchorCfg = spellCfg.anchor
local texts = cfg.texts
local actions = cfg.commands.lightActions
local RPC = VavaMagic.RPC
local STATES = VavaMagic.STATES
local NAME = 'lueur'
-- l'orbe se pose un peu en deçà de ce que l'on vise, pour ne pas entrer dans le mur
local ANCHOR_PULLBACK = 0.3

-- premier niveau qui permet d'ancrer un orbe
local ANCHOR_LEVEL = nil
for level, levelCfg in ipairs(spellCfg.levels) do
    if levelCfg.anchor and not ANCHOR_LEVEL then ANCHOR_LEVEL = level end
end

local lueur = {}
VavaMagic.lueur = lueur

---@param kind string
local function putOut(kind)
    CreateThread(function()
        local transport, success, code = core.rpc.call(RPC.LIGHT_OFF, kind)
        if not transport or not success then messages.refuse(transport and code or success) end
    end)
end

--- Touche : allumer, ou éteindre si sa lumière brille.
function lueur.toggle()
    if Entity(PlayerPedId()).state[STATES.LIGHT] ~= nil then
        putOut('light')
        return
    end
    casting.start(NAME, { args = { 'light' }, count = 1 })
end

--- Touche : ancrer un orbe là où l'on regarde (à portée de la main ; le serveur revérifie).
function lueur.anchor()
    if not ANCHOR_LEVEL then return end
    local point = aim.point(anchorCfg.reach, ANCHOR_PULLBACK)
    casting.start(NAME, {
        args = { 'anchor', point.x, point.y, point.z }, count = 4, minLevel = ANCHOR_LEVEL, costShare = anchorCfg.costShare,
    })
end

--- Couleur de la lumière (niveau 5).
---@param name string
function lueur.setColor(name)
    CreateThread(function()
        local transport, success, code = core.rpc.call(RPC.LIGHT_COLOR, name)
        if not transport or not success then messages.refuse(transport and code or success) end
    end)
end

keys.bind('lueur', lueur.toggle)
keys.bind('ancre', lueur.anchor)

keys.command(cfg.commands.lueur, texts.suggestions.lueur, function(args)
    local action = lower(args[1] or '')
    if action == '' then
        lueur.toggle()
    elseif action == actions.anchor then
        lueur.anchor()
    elseif action == actions.off then
        putOut('light')
    elseif action == actions.dispel then
        putOut('anchors')
    elseif action == actions.color then
        if args[2] then
            lueur.setColor(lower(args[2]))
        else
            local names = {}
            for _, color in ipairs(spellCfg.colors) do names[#names + 1] = color.name end
            bridge.ChatLines({ texts.chat.colorsList:format(concat(names, ', ')) })
        end
    else
        bridge.ChatLines({ texts.chat.lightUsage })
    end
end)
