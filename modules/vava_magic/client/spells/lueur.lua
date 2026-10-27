--[[
    vava_magic/client/spells/lueur.lua
    Rôle : sort Lueur côté client : clic gauche en mode magie = allumer (incantation) ou éteindre sa lumière ; en
           visant (niveau 4) = ancrer un orbe au point visé (position revérifiée par le serveur) ; couleur au niveau 5
           (grimoire ou /lueur couleur). Le rendu de toutes les lumières est dans client/ambient.lua.
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local ipairs, lower = ipairs, string.lower
local concat = table.concat
local CreateThread, PlayerPedId, Entity, GetEntityCoords = CreateThread, PlayerPedId, Entity, GetEntityCoords

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local aim = VavaMagic.aim
local geometry = VavaMagic.geometry
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

--- Allumer, ou éteindre si sa lumière brille.
function lueur.toggle()
    if Entity(PlayerPedId()).state[STATES.LIGHT] ~= nil then
        putOut('light')
        return
    end
    casting.start(NAME, { args = { 'light' }, count = 1 })
end

--- Ancrer un orbe en un point (à portée de la main ; le serveur revérifie). Sans point : là où l'on regarde.
---@param point table|nil
function lueur.anchor(point)
    if not ANCHOR_LEVEL then return end
    point = point or aim.point(anchorCfg.reach, ANCHOR_PULLBACK)
    casting.start(NAME, {
        args = { 'anchor', point.x, point.y, point.z }, count = 4, minLevel = ANCHOR_LEVEL, costShare = anchorCfg.costShare,
    })
end

--- Clic gauche en mode magie : en visant au niveau qui le permet, ancrer un orbe au point visé (un peu en deçà, pour
--- ne pas entrer dans le mur) ; sinon allumer ou éteindre.
---@param info table  { aiming, point, inRange }
local function cast(info)
    if not info.aiming then
        lueur.toggle()
        return
    end
    if not info.point or not info.inRange then
        messages.refuse('too_far')
        return
    end
    local body = GetEntityCoords(PlayerPedId())
    local back = geometry.normalize(body.x - info.point.x, body.y - info.point.y, body.z - info.point.z)
    local point = info.point
    if back then point = { x = point.x + back.x * ANCHOR_PULLBACK, y = point.y + back.y * ANCHOR_PULLBACK, z = point.z + back.z * ANCHOR_PULLBACK } end
    lueur.anchor(point)
end

--- Couleur de la lumière (niveau 5).
---@param name string
function lueur.setColor(name)
    CreateThread(function()
        local transport, success, code = core.rpc.call(RPC.LIGHT_COLOR, name)
        if not transport or not success then messages.refuse(transport and code or success) end
    end)
end

controls.register(NAME, { cast = cast })

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
