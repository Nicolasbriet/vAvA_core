--[[
    vava_magic/server/progression.lua
    Rôle : XP des sorts, décidée par le serveur. Un sort réussi rapporte son XP, un échec la moitié (config) ; un même
           sort ne rapporte qu'une fois par intervalle (anti-farm). Un sort qui touche une cible rapporte en plus son
           bonus (`hitXp`), seulement si son lancer a rapporté. Passage de niveau : message au joueur avec ce que le
           niveau débloque, hook `vava_magic:levelUp`.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/sheets.lua (server/spells.lua à
                  l'exécution)
]]

local floor, min, max = math.floor, math.min, math.max
local GetGameTimer = GetGameTimer

local bridge = VavaMagic.bridge
local sheets = VavaMagic.sheets
local progression = VavaMagic.progression
local cfg = VavaMagic.config.progression
local texts = VavaMagic.config.texts.notify
local HOOKS = VavaMagic.HOOKS
local MAX_XP = progression.MAX_XP

local experience = {}
VavaMagic.experience = experience

---@type table<integer, table<string, integer>>  dernier gain d'XP par joueur et par sort
local lastGain = {}

--- Annonce un passage de niveau.
---@param src integer
---@param spell string
---@param level integer
local function announce(src, spell, level)
    local def = VavaMagic.spells.get(spell)
    if not def then return end
    local levelCfg = def.config.levels[level]
    bridge.Notify(src, texts.levelUp:format(def.config.label, level, levelCfg.unlock), 'success')
    VavaMagic.core.hooks.runAfter(HOOKS.LEVEL, { source = src, characterId = sheets.get(src).characterId, spell = spell, level = level })
end

--- XP d'un sort lancé : succès (toute l'XP) ou échec (une part). Renvoie l'XP gagnée.
---@param src integer
---@param spell string
---@param success boolean
---@return integer
function experience.grant(src, spell, success)
    local sheet = sheets.get(src)
    local entry = sheet and sheet.spells[spell]
    local def = VavaMagic.spells.get(spell)
    if not entry or not def then return 0 end
    local now = GetGameTimer()
    local gains = lastGain[src]
    if not gains then
        gains = {}
        lastGain[src] = gains
    end
    if gains[spell] and now - gains[spell] < cfg.antiFarmMs then return 0 end
    local amount = floor(def.config.xp * (success and 1 or cfg.failureShare) + 0.5)
    if amount <= 0 or entry.xp >= MAX_XP then return 0 end
    gains[spell] = now
    local before = progression.levelOf(entry.xp)
    entry.xp = min(MAX_XP, entry.xp + amount)
    local after = progression.levelOf(entry.xp)
    sheets.touch(src, true)
    for level = before + 1, after do announce(src, spell, level) end
    return amount
end

--- Ajoute de l'XP à un sort connu, sans l'anti-farm (bonus d'un lancer qui a déjà rapporté). Renvoie l'XP gagnée.
---@param src integer
---@param spell string
---@param amount integer
---@return integer
function experience.bonus(src, spell, amount)
    local sheet = sheets.get(src)
    local entry = sheet and sheet.spells[spell]
    if not entry or amount <= 0 or entry.xp >= MAX_XP then return 0 end
    local before = progression.levelOf(entry.xp)
    local gained = min(MAX_XP, entry.xp + amount) - entry.xp
    entry.xp = entry.xp + gained
    sheets.touch(src, true)
    for level = before + 1, progression.levelOf(entry.xp) do announce(src, spell, level) end
    return gained
end

--- Fixe l'XP d'un sort connu (Conseil). Les niveaux gagnés sont annoncés.
---@param src integer
---@param spell string
---@param value integer
---@return boolean
function experience.set(src, spell, value)
    local sheet = sheets.get(src)
    local entry = sheet and sheet.spells[spell]
    if not entry then return false end
    local before = progression.levelOf(entry.xp)
    entry.xp = max(0, min(MAX_XP, value))
    local after = progression.levelOf(entry.xp)
    sheets.touch(src, true)
    for level = before + 1, after do announce(src, spell, level) end
    return true
end

---@param src integer
function experience.forget(src)
    lastGain[src] = nil
end
