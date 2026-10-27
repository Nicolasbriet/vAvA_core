--[[
    vava_magic/server/spells/lueur.lua
    Rôle : sort Lueur (lumière), décidé par le serveur.
      - Lumière portée : state bag sur le ped du lanceur (dans la main aux niveaux 1-2, orbe près de l'épaule
        ensuite), vu des seuls joueurs proches ; éteinte par le serveur à expiration, ou à la demande.
      - Orbe ancré (niveau 4) : position proposée par le client, revérifiée (portée depuis le lanceur, position lue
        côté serveur) ; objet réseau invisible créé par le serveur, porteur de l'état de la lumière, supprimé par lui à
        expiration. Un orbe par mage (le plus ancien cède sa place), plafond pour tout le royaume.
      - Couleur au choix (niveau 5), gardée dans la fiche.
    Dépendances : shared/, config.lua, server/ (noyau)
]]

local ipairs, pairs, tostring = ipairs, pairs, tostring
local GetHashKey, CreateObjectNoOffset, FreezeEntityPosition, DoesEntityExist, DeleteEntity, Entity, SetTimeout =
    GetHashKey, CreateObjectNoOffset, FreezeEntityPosition, DoesEntityExist, DeleteEntity, Entity, SetTimeout

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local spells = VavaMagic.spells
local progression = VavaMagic.progression
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.lueur
local anchorCfg = spellCfg.anchor
local notify = cfg.texts.notify
local limits = cfg.rateLimits
local RPC = VavaMagic.RPC
local STATES = VavaMagic.STATES
local NAME = 'lueur'
local MODE = { LIGHT = 'light', ANCHOR = 'anchor' }
local OFF = { LIGHT = 'light', ANCHORS = 'anchors' }
local ORB_MODE = 'orb'
local COORD = { type = 'number', min = -20000, max = 20000, optional = true }
local MODEL = GetHashKey(anchorCfg.model)

---@type table<integer, integer>  joueur → jeton de sa lumière portée
local lights = {}
---@type table<integer, { entity: integer, owner: integer }>
local anchors = {}
local anchorCount = 0
local nextAnchor = 0

---@param name string|nil
---@return table
local function colorNamed(name)
    for _, color in ipairs(spellCfg.colors) do
        if color.name == name then return color end
    end
    return nil
end

--- Couleur de la lumière : choisie au niveau qui le permet, sinon celle par défaut.
---@param sheet table
---@param levelCfg table
---@return table
local function colorOf(sheet, levelCfg)
    return (levelCfg.colors and colorNamed(sheet.lightColor)) or colorNamed(spellCfg.defaultColor) or spellCfg.colors[1]
end

---@param levelCfg table
---@param color table
---@param mode string
---@return table
local function stateOf(levelCfg, color, mode)
    return {
        mode = mode, r = color.r, g = color.g, b = color.b,
        range = levelCfg.range, intensity = levelCfg.intensity, flicker = levelCfg.flicker,
    }
end

--- Éteint la lumière portée du joueur.
---@param src integer
---@return boolean  vrai si elle brillait
local function putOut(src)
    if not lights[src] then return false end
    lights[src] = nil
    world.setState(src, STATES.LIGHT, nil)
    return true
end

---@param id integer
local function removeAnchor(id)
    local anchor = anchors[id]
    if not anchor then return end
    anchors[id] = nil
    anchorCount = anchorCount - 1
    if DoesEntityExist(anchor.entity) then DeleteEntity(anchor.entity) end
end

--- Orbes ancrés d'un joueur, du plus ancien au plus récent.
---@param src integer
---@return integer[]
local function anchorsOf(src)
    local list = {}
    for id, anchor in pairs(anchors) do
        if anchor.owner == src then list[#list + 1] = id end
    end
    table.sort(list)
    return list
end

---@param ctx table
---@param mode string
local function begin(ctx, mode, x, y, z)
    if mode ~= MODE.ANCHOR then return true, { mode = MODE.LIGHT } end
    local levelCfg = spellCfg.levels[ctx.level]
    if not levelCfg.anchor then return false, 'level_too_low' end
    if not x or not y or not z then return false, 'invalid' end
    local point = { x = x, y = y, z = z }
    if geometry.distance(ctx.origin, point) > anchorCfg.reach + cfg.casting.moveMargin then return false, 'too_far' end
    if anchorCount >= anchorCfg.max and #anchorsOf(ctx.source) < anchorCfg.perCaster then return false, 'anchor_limit' end
    return true, { mode = MODE.ANCHOR, x = x, y = y, z = z }, progression.cost(spellCfg, ctx.level, anchorCfg.costShare)
end

---@param ctx table
local function finish(ctx)
    local src, data = ctx.source, ctx.data
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    local levelCfg = spellCfg.levels[ctx.level]
    local color = colorOf(sheet, levelCfg)

    if data.mode == MODE.LIGHT then
        world.setState(src, STATES.LIGHT, stateOf(levelCfg, color, levelCfg.mode))
        local token = (lights[src] or 0) + 1
        lights[src] = token
        SetTimeout(levelCfg.durationMs, function()
            if lights[src] == token and putOut(src) then bridge.Notify(src, notify.lightOff, 'info') end
        end)
        return { success = true }
    end

    -- orbe ancré : le plus ancien du lanceur cède sa place
    local own = anchorsOf(src)
    for i = 1, #own - anchorCfg.perCaster + 1 do removeAnchor(own[i]) end
    if anchorCount >= anchorCfg.max then return false, 'anchor_limit' end
    local entity = CreateObjectNoOffset(MODEL, data.x, data.y, data.z, true, true, false)
    if not entity or entity == 0 then return false, 'refused' end
    FreezeEntityPosition(entity, true)
    Entity(entity).state:set(STATES.ORB, stateOf(levelCfg, color, ORB_MODE), true)
    nextAnchor = nextAnchor + 1
    local id = nextAnchor
    anchors[id] = { entity = entity, owner = src }
    anchorCount = anchorCount + 1
    SetTimeout(levelCfg.anchorMs, function() removeAnchor(id) end)
    bridge.Notify(src, notify.anchored, 'success')
    return { success = true }
end

--- Éteindre sa lumière portée ('light') ou dissiper ses orbes ancrés ('anchors').
local function off(src, kind)
    if kind == OFF.ANCHORS then
        local own = anchorsOf(src)
        if #own == 0 then return false, 'no_light' end
        for _, id in ipairs(own) do removeAnchor(id) end
        bridge.Notify(src, notify.dispelled, 'info')
        return true
    end
    if not putOut(src) then return false, 'no_light' end
    bridge.Notify(src, notify.lightOff, 'info')
    return true
end

--- Choisit la couleur de sa lumière (niveau qui le permet) ; une lumière qui brille la prend aussitôt.
local function setColor(src, name)
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    local level = sheets.level(src, NAME)
    if not sheet.isMage or not level then return false, 'unknown_spell' end
    local levelCfg = spellCfg.levels[level]
    if not levelCfg.colors then return false, 'level_too_low' end
    local color = colorNamed(name)
    if not color then return false, 'unknown_color' end
    sheet.lightColor = color.name
    sheets.touch(src, true)
    if lights[src] then world.setState(src, STATES.LIGHT, stateOf(levelCfg, color, levelCfg.mode)) end
    bridge.Notify(src, notify.colorSet:format(color.label), 'success')
    return true
end

local colorNames = {}
for _, color in ipairs(spellCfg.colors) do colorNames[#colorNames + 1] = color.name end

spells.addRpc(RPC.LIGHT_OFF, { { type = 'string', enum = { OFF.LIGHT, OFF.ANCHORS } } }, limits.light, off)
spells.addRpc(RPC.LIGHT_COLOR, { { type = 'string', enum = colorNames } }, limits.light, setColor)

spells.onLeave(function(src)
    lights[src] = nil
    for _, id in ipairs(anchorsOf(src)) do removeAnchor(id) end
end)
spells.onStop(function()
    for id in pairs(anchors) do removeAnchor(id) end
end)

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = { { type = 'string', enum = { MODE.LIGHT, MODE.ANCHOR } }, COORD, COORD, COORD },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Lueur non déclarée : %s', tostring(err)) end
