--[[
    vava_magic/server/admin.lua
    Rôle : commandes du Conseil (`/magie …`, aussi depuis la console du serveur), protégées par Bridge.IsAdmin :
           mage ou non, apprendre / retirer un sort, niveau ou XP d'un sort, remplir la mana, fiche d'un joueur, donner
           un grimoire ou un registre. Chaque commande est inscrite au journal du Registre du Conseil.
    Dépendances : shared/, config.lua, server/ (noyau)
]]

local ipairs, pairs, tonumber, tostring, concat = ipairs, pairs, tonumber, tostring, table.concat
local tointeger, lower = math.tointeger, string.lower
local CreateThread, RegisterCommand, TriggerClientEvent = CreateThread, RegisterCommand, TriggerClientEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local sheets = VavaMagic.sheets
local mana = VavaMagic.mana
local casting = VavaMagic.casting
local experience = VavaMagic.experience
local spells = VavaMagic.spells
local registers = VavaMagic.registers
local progression = VavaMagic.progression
local cfg = VavaMagic.config
local commands = cfg.commands
local actions = commands.adminActions
local chat = cfg.texts.chat
local notify = cfg.texts.notify
local logs = cfg.texts.logs
local items = cfg.items
local EVENTS = VavaMagic.EVENTS
local HOOKS = VavaMagic.HOOKS
local CONSOLE = 0

local admin = {}
VavaMagic.admin = admin

--- Réponse à l'auteur de la commande : chat en jeu, console sinon.
---@param src integer
---@param lines string[]
local function reply(src, lines)
    if src == CONSOLE then
        for _, line in ipairs(lines) do print(('[%s] %s'):format(VavaMagic.resource, line)) end
        return
    end
    TriggerClientEvent(EVENTS.CHAT, src, lines)
end

--- Joueur visé (numéro de joueur dont le personnage est en jeu), ou nil.
---@param value string|nil
---@return integer|nil
local function targetOf(value)
    local id = tointeger(tonumber(value))
    if id and sheets.get(id) then return id end
    return nil
end

---@param value string|nil
---@return string|nil
local function spellOf(value)
    local name = value and lower(value)
    if name and spells.get(name) then return name end
    return nil
end

---@param target integer
---@return table
local function details(target, extra)
    local entry = { joueur = target, personnage = sheets.get(target).characterId }
    for key, value in pairs(extra or {}) do entry[key] = value end
    return entry
end

local handlers = {}

handlers[actions.mage] = function(src, target, args)
    local word = lower(args[3] or '')
    if word ~= commands.yes and word ~= commands.no then return false, 'invalid' end
    local sheet = sheets.get(target)
    local isMage = word == commands.yes
    if sheet.isMage ~= isMage then
        sheet.isMage = isMage
        if isMage then
            mana.start(target)
        else
            casting.abort(target, 'not_mage', true)
            mana.stop(target)
        end
        sheets.touch(target, true)
        bridge.Notify(target, isMage and notify.becameMage or notify.lostMagic, 'info')
        core.hooks.runAfter(HOOKS.MAGE, { source = target, characterId = sheet.characterId, isMage = isMage })
    end
    bridge.AdminLog(src, logs.mage, details(target, { mage = word }))
    return true
end

handlers[actions.learn] = function(src, target, args)
    local spell = spellOf(args[3])
    if not spell then return false, 'unknown_spell' end
    local sheet = sheets.get(target)
    if not sheet.spells[spell] then
        sheet.spells[spell] = { xp = 0 }
        sheets.touch(target, true)
        bridge.Notify(target, notify.learned:format(spells.get(spell).config.label), 'success')
    end
    bridge.AdminLog(src, logs.learn, details(target, { sort = spell }))
    return true
end

handlers[actions.forget] = function(src, target, args)
    local spell = spellOf(args[3])
    if not spell then return false, 'unknown_spell' end
    local sheet = sheets.get(target)
    if sheet.spells[spell] then
        local cast = casting.current(target)
        if cast and cast.spell == spell then casting.abort(target, 'unknown_spell', true) end
        sheet.spells[spell] = nil
        sheets.touch(target, true)
        bridge.Notify(target, notify.forgotten:format(spells.get(spell).config.label), 'info')
    end
    bridge.AdminLog(src, logs.forget, details(target, { sort = spell }))
    return true
end

--- Fixe l'XP (le sort est appris s'il ne l'était pas).
local function setXp(target, spell, value)
    local sheet = sheets.get(target)
    if not sheet.spells[spell] then
        sheet.spells[spell] = { xp = 0 }
        bridge.Notify(target, notify.learned:format(spells.get(spell).config.label), 'success')
    end
    return experience.set(target, spell, value)
end

handlers[actions.level] = function(src, target, args)
    local spell = spellOf(args[3])
    if not spell then return false, 'unknown_spell' end
    local level = tointeger(tonumber(args[4]))
    if not level or level < 1 or level > progression.MAX_LEVEL then return false, 'invalid' end
    setXp(target, spell, progression.threshold(level))
    bridge.AdminLog(src, logs.level, details(target, { sort = spell, niveau = level }))
    return true
end

handlers[actions.xp] = function(src, target, args)
    local spell = spellOf(args[3])
    if not spell then return false, 'unknown_spell' end
    local value = tointeger(tonumber(args[4]))
    if not value or value < 0 then return false, 'invalid' end
    setXp(target, spell, value)
    bridge.AdminLog(src, logs.xp, details(target, { sort = spell, xp = value }))
    return true
end

handlers[actions.mana] = function(src, target)
    if not mana.refill(target) then return false, 'not_mage' end
    bridge.Notify(target, notify.manaRefilled, 'success')
    bridge.AdminLog(src, logs.mana, details(target))
    return true
end

handlers[actions.sheet] = function(src, target)
    local sheet = sheets.get(target)
    local lines = {
        chat.sheetTitle:format(bridge.GetCharacterName(target) or '?', target),
        chat.sheetMage:format(sheet.isMage and chat.yes or chat.no),
    }
    local known = 0
    for _, name in ipairs(spells.names()) do
        local entry = sheet.spells[name]
        if entry then
            known = known + 1
            lines[#lines + 1] = chat.sheetSpell:format(spells.get(name).config.label, progression.levelOf(entry.xp), entry.xp)
        end
    end
    if known == 0 then lines[#lines + 1] = chat.sheetNoSpell end
    lines[#lines + 1] = chat.sheetSigils:format(#sheet.sigils, mana.current(target), mana.MAX)
    reply(src, lines)
    bridge.AdminLog(src, logs.sheet, details(target))
    return true, true
end

handlers[actions.give] = function(src, target, args)
    local kind = lower(args[3] or '')
    local ok, code
    if kind == items.grimoire.name then
        ok, code = bridge.AddItem(target, items.grimoire.name, 1)
    elseif kind == items.registre.name then
        local id = registers.create()
        if not id then return false, 'db_error' end
        ok, code = bridge.AddItem(target, items.registre.name, 1, registers.metadata(id))
    else
        return false, 'invalid'
    end
    if not ok then return false, code end
    bridge.AdminLog(src, logs.give, details(target, { objet = kind }))
    return true
end

---@param src integer
---@param args string[]
local function run(src, args)
    if not bridge.IsAdmin(src) then
        reply(src, { chat.adminForbidden })
        return
    end
    local handler = handlers[lower(args[1] or '')]
    if not handler then
        reply(src, { chat.adminUsage })
        return
    end
    local target = targetOf(args[2])
    if not target then
        reply(src, { chat.adminNoTarget })
        return
    end
    local ok, result = handler(src, target, args)
    if ok then
        if result ~= true then reply(src, { chat.adminDone }) end
    elseif result == 'unknown_spell' then
        reply(src, { chat.adminUnknownSpell:format(concat(spells.names(), ', ')) })
    elseif result == 'invalid' then
        reply(src, { chat.adminUsage })
    else
        reply(src, { chat.adminFailed:format(tostring(result)) })
    end
end

--- Déclare la commande. Appelé pendant le setup du module.
function admin.start()
    RegisterCommand(commands.admin, function(source, args)
        local src = tointeger(tonumber(source)) or CONSOLE
        CreateThread(function() run(src, args or {}) end)
    end, false)
end
