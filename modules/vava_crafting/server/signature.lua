--[[
    vava_crafting/server/signature.lua
    Rôle : ce qui fait d'une pièce un objet qui porte une histoire : le poinçon de l'artisan (glyphe de la config,
           champ de personnage, dès le rang requis dans une compétence d'artisanat), les métadonnées d'un objet signé à
           sa création (qualité, palier, solidité, créateur figé, poinçon, date, histoire), l'histoire bornée (création
           + les dernières entrées), le baptême d'un chef-d'œuvre pendant la fenêtre qui suit sa création.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local format = string.format
local utf8codes, utf8len = utf8.codes, utf8.len
local GetGameTimer = GetGameTimer
local time = os.time

local bridge = VavaCrafting.bridge
local journal = VavaCrafting.journal
local catalog = VavaCrafting.catalog
local cfg = VavaCrafting.config
local markCfg, nameCfg, messages = cfg.mark, cfg.masterpiece, cfg.messages

local signature = {}
VavaCrafting.signature = signature

-- glyphes autorisés
local glyphs = {}
for _, glyph in ipairs(markCfg.glyphs) do glyphs[glyph] = true end
-- lettres et séparateurs admis dans un nom (points de code)
local letters, separators = {}, {}
for _, code in utf8codes(nameCfg.nameLetters) do letters[code] = true end
for _, code in utf8codes(nameCfg.nameSeparators) do separators[code] = true end

---@class vAvA.PendingName
---@field instanceId integer
---@field label string
---@field until_ integer  GetGameTimer

---@type table<integer, vAvA.PendingName>
local pendingNames = {}

--- Déclare le champ du poinçon. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function signature.define()
    return bridge.DefineMarkField({ type = 'string', min = 1, max = 8 })
end

--- Compétences d'artisanat : celles servies par au moins un type de station.
---@return string[]
local function craftingSkills()
    local set, list = {}, {}
    for _, kind in pairs(cfg.stationTypes) do
        for _, skill in ipairs(kind.skills) do
            if not set[skill] then
                set[skill] = true
                list[#list + 1] = skill
            end
        end
    end
    return list
end

--- Le joueur a-t-il le rang pour choisir un poinçon (dans une compétence d'artisanat au moins) ?
---@param src integer
---@return boolean
function signature.canMark(src)
    for _, skill in ipairs(craftingSkills()) do
        if bridge.HasRank(src, skill, markCfg.minRank) then return true end
    end
    return false
end

---@param characterId integer
---@return string|nil
function signature.markOf(characterId)
    return bridge.GetMark(characterId)
end

--- Choisit son poinçon.
---@param src integer
---@param glyph any
---@return boolean ok
---@return string|nil code
function signature.setMark(src, glyph)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if type(glyph) ~= 'string' or not glyphs[glyph] then return false, 'invalid_mark' end
    if not signature.canMark(src) then return false, 'rank' end
    if not bridge.SetMark(characterId, glyph) then return false, 'db_error' end
    bridge.Notify(src, format(messages.markSet, glyph), 'info')
    return true
end

--- Vue du poinçon pour le menu : { current, glyphs, allowed }.
---@param src integer
---@param characterId integer
---@return table
function signature.view(src, characterId)
    local list = {}
    for i, glyph in ipairs(markCfg.glyphs) do list[i] = glyph end
    return { current = bridge.GetMark(characterId), glyphs = list, allowed = signature.canMark(src) }
end

-- Métadonnées -----------------------------------------------------------------------------------------------------

--- Histoire bornée : la création (première entrée) et les dernières entrées.
---@param history table[]
---@return table[]
function signature.trimHistory(history)
    local maximum = cfg.history.max
    if #history <= maximum then return history end
    local kept = { history[1] }
    for i = #history - (maximum - 2), #history do kept[#kept + 1] = history[i] end
    return kept
end

--- Copie de l'histoire d'un objet avec une entrée de plus.
---@param metadata table
---@param entry { at: integer, kind: string, by: string, note?: string }
---@return table[]
function signature.appendHistory(metadata, entry)
    local history = {}
    if type(metadata.history) == 'table' then
        for i, past in ipairs(metadata.history) do history[i] = past end
    end
    history[#history + 1] = entry
    return signature.trimHistory(history)
end

--- Métadonnées d'un objet signé à sa création.
---@param characterId integer
---@param name string
---@param recipe vAvA.RecipeDefinition
---@param quality integer
---@param tier integer
---@param now integer
---@return table
function signature.build(characterId, name, recipe, quality, tier, now)
    local metadata = {
        quality = quality, tier = tier, durability = recipe.durability, max_durability = recipe.durability,
        crafter_id = characterId, crafter_name = name, crafted_at = now,
        history = { { at = now, kind = 'creation', by = name } },
    }
    local mark = bridge.GetMark(characterId)
    if mark then metadata.mark = mark end
    return metadata
end

--- Métadonnées d'un produit simple.
---@param tier integer
---@return table
function signature.simple(tier)
    return { tier = tier }
end

-- Baptême -----------------------------------------------------------------------------------------------------------

--- Un chef-d'œuvre vient d'être créé : son artisan peut le baptiser pendant la fenêtre.
---@param src integer
---@param instanceId integer
---@param label string
function signature.offerName(src, instanceId, label)
    pendingNames[src] = { instanceId = instanceId, label = label, until_ = GetGameTimer() + nameCfg.nameWindowMs }
end

--- Valide et normalise un nom propre (lettres, séparateurs jamais en tête, en fin ni doublés).
---@param value any
---@return string|nil
local function validName(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    local length = utf8len(value)
    if not length or length < nameCfg.nameMin or length > nameCfg.nameMax then return nil end
    local afterSeparator = true
    for _, code in utf8codes(value) do
        if separators[code] then
            if afterSeparator then return nil end
            afterSeparator = true
        elseif letters[code] then
            afterSeparator = false
        else
            return nil
        end
    end
    if afterSeparator then return nil end
    return value
end

--- Baptise le chef-d'œuvre en attente. Bloque le thread courant (inventaire).
---@param src integer
---@param instanceId any
---@param name any
---@return boolean ok
---@return string|nil code
function signature.name(src, instanceId, name)
    local pending = pendingNames[src]
    if not pending or pending.instanceId ~= instanceId then return false, 'not_found' end
    if GetGameTimer() > pending.until_ then
        pendingNames[src] = nil
        return false, 'expired'
    end
    local clean = validName(name)
    if not clean then return false, 'invalid_name' end
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    local instance
    for _, candidate in ipairs(bridge.Items(src)) do
        if candidate.id == instanceId then instance = candidate end
    end
    if not instance or type(instance.metadata) ~= 'table' or instance.metadata.crafter_id ~= characterId then
        pendingNames[src] = nil
        return false, 'not_found'
    end
    if instance.metadata.name then
        pendingNames[src] = nil
        return false, 'not_found'
    end
    local who = bridge.GetCharacterName(src) or '?'
    local ok = bridge.PatchMetadata(src, instanceId, { name = clean, history = signature.appendHistory(instance.metadata, { at = time(), kind = 'rename', by = who, note = clean }) })
    if not ok then return false, 'not_found' end
    pendingNames[src] = nil
    journal.write('named', { characterId = characterId, item = instance.item, quality = instance.metadata.quality, details = { name = clean, instance = instanceId } })
    bridge.Notify(src, format(messages.named, catalog.itemLabel(instance.item), clean), 'info')
    return true
end

--- Joueur parti : son baptême en attente tombe.
---@param src integer
function signature.forget(src)
    pendingNames[src] = nil
end

signature.craftingSkills = craftingSkills
