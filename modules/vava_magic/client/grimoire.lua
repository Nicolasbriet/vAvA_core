--[[
    vava_magic/client/grimoire.lua
    Rôle : grimoire (objet utilisé, ou /grimoire en secours) : sorts connus avec leur niveau, barre d'XP, ce que le
           niveau permet, ce que débloque le suivant, coût en mana, recharge, touche choisie par le joueur ; couleur
           de la lumière quand le niveau le permet. Pour un non-mage, les pages restent illisibles.
           Construit d'après la vue de la fiche reçue du serveur et la config (aucune requête).
    Dépendances : shared/, config.lua, client/ (noyau), client/spells/lueur.lua (couleur)
]]

local type, ipairs, ceil = type, ipairs, math.ceil
local RegisterNetEvent = RegisterNetEvent

local nui = VavaMagic.nui
local state = VavaMagic.state
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local progression = VavaMagic.progression
local cfg = VavaMagic.config
local EVENTS = VavaMagic.EVENTS
local MS_PER_SECOND = 1000

local grimoire = {}
VavaMagic.grimoire = grimoire

---@param spellCfg table
---@param levelCfg table
---@return table|nil
local function colorsOf(spellCfg, levelCfg)
    if not levelCfg.colors or not spellCfg.colors then return nil end
    local list = {}
    for _, color in ipairs(spellCfg.colors) do
        list[#list + 1] = { name = color.name, label = color.label, r = color.r, g = color.g, b = color.b }
    end
    return list
end

--- Page d'un sort connu.
---@param name string
---@param view table
---@return table
local function pageOf(name, view)
    local spellCfg = state.spellConfig(name)
    local level, xp = state.level(name), state.xp(name)
    local levelCfg, nextCfg = spellCfg.levels[level], spellCfg.levels[level + 1]
    local colors = colorsOf(spellCfg, levelCfg)
    return {
        name = name, label = spellCfg.label, summary = spellCfg.summary, level = level, xp = xp,
        from = progression.threshold(level), to = nextCfg and progression.threshold(level + 1) or nil,
        description = levelCfg.description, next = nextCfg and nextCfg.unlock or nil,
        cost = progression.cost(spellCfg, level), cooldown = ceil(levelCfg.cooldownMs / MS_PER_SECOND),
        key = spellCfg.key and keys.label(spellCfg.key) or nil,
        lock = spellCfg.lockOn and keys.label('cible') or nil,
        sigils = name == cfg.sigils.spell and view.sigilLimit or nil,
        colors = colors, color = colors and (view.lightColor ~= '' and view.lightColor or spellCfg.defaultColor) or nil,
    }
end

function grimoire.open()
    if not state.ready() then
        messages.refuse('not_ready')
        return
    end
    if not state.isMage() then
        nui.open('grimoire', { sealed = true })
        return
    end
    local view = state.view()
    local pages = {}
    for _, name in ipairs(state.knownSpells()) do pages[#pages + 1] = pageOf(name, view) end
    nui.open('grimoire', { sealed = false, spells = pages })
end

nui.on('grimoire:color', function(data)
    local name = data.name
    if type(name) == 'string' and VavaMagic.lueur then VavaMagic.lueur.setColor(name) end
    return { ok = true }
end)

RegisterNetEvent(EVENTS.GRIMOIRE, grimoire.open)

keys.command(cfg.commands.grimoire, cfg.texts.suggestions.grimoire, grimoire.open)
