--[[
    vava_magic/server/sheets.lua
    Rôle : fiches magie des personnages en jeu, décidées par le serveur : mage ou non, sorts connus et leur XP, sort
           prêt dans les mains (choisi dans la roue), combinaisons d'éléments découvertes, sigils gardés (contacts du
           Murmure), sigil du personnage, couleur de lumière, dernier registre ouvert.
      - Chargée à l'arrivée du personnage (une neuve s'il n'en a jamais eu) ; son sigil est unique dans tout le
        royaume (table vava_magic_sigils), tiré au hasard la première fois. Rien n'est gardé d'un joueur parti
        pendant la lecture (son départ est déjà passé).
      - Gardée en mémoire ; écrite dans le personnage au plus toutes les `persistence.flushMs` si elle a changé,
        et aussitôt au départ (le core la sauvegarde en base avec le personnage).
      - Index des sigils des joueurs en jeu, pour délivrer un murmure sans requête.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local floor, random, tointeger = math.floor, math.random, math.tointeger
local sub, concat = string.sub, table.concat
local TriggerClientEvent, SetTimeout = TriggerClientEvent, SetTimeout

local bridge = VavaMagic.bridge
local progression = VavaMagic.progression
local cfg = VavaMagic.config
local sigilCfg = cfg.sigils
local EVENTS = VavaMagic.EVENTS
local MAX_XP = progression.MAX_XP

-- plus grand nombre de sigils qu'un personnage peut garder, tous niveaux confondus
local SIGILS_MAX = sigilCfg.nonMageLimit
for _, spell in pairs(cfg.spells) do
    for _, level in ipairs(spell.levels) do
        if level.sigils and level.sigils > SIGILS_MAX then SIGILS_MAX = level.sigils end
    end
end
local SIGIL_PATTERN = '^[' .. sigilCfg.alphabet .. ']+$'
local SPELL_NAME = { type = 'string', min = 1, max = 32, pattern = '^[%w_]+$' }
-- combinaisons découvertes gardées au plus (grimoire)
local COMBOS_MAX = 32
local SIGIL = { type = 'string', min = sigilCfg.length, max = sigilCfg.length, pattern = SIGIL_PATTERN }

local SELECT_SIGIL = 'SELECT `sigil` FROM `vava_magic_sigils` WHERE `character_id` = ?'
local INSERT_SIGIL = 'INSERT INTO `vava_magic_sigils` (`sigil`, `character_id`) VALUES (?, ?)'
local UPDATE_SIGIL = 'UPDATE `vava_magic_sigils` SET `sigil` = ? WHERE `character_id` = ?'
local DELETE_SIGIL = 'DELETE FROM `vava_magic_sigils` WHERE `character_id` = ?'

local sheets = {}
VavaMagic.sheets = sheets

sheets.SIGILS_MAX = SIGILS_MAX

--- Schéma du champ de personnage (validé par le core à chaque écriture).
sheets.SCHEMA = {
    type = 'table',
    fields = {
        isMage = { type = 'boolean' },
        sigil = SIGIL,
        spells = { type = 'map', max = 32, key = SPELL_NAME, value = { type = 'table', fields = { xp = { type = 'integer', min = 0, max = MAX_XP } } } },
        sigils = { type = 'array', max = SIGILS_MAX, items = { type = 'table', fields = {
            sigil = SIGIL,
            name = { type = 'string', min = 1, max = sigilCfg.nameMax * 4 },
        } } },
        selectedSpell = { type = 'string', min = 1, max = 32, pattern = '^[%w_]+$', optional = true },
        discoveredCombos = { type = 'array', max = COMBOS_MAX, items = { type = 'string', min = 1, max = 32, pattern = '^[%w_]+$' }, optional = true },
        lightColor = { type = 'string', max = 32, optional = true },
        register = { type = 'integer', min = 1, optional = true },
        scrambledAt = { type = 'integer', min = 0, optional = true }, -- dernier brouillage (secondes, horloge du serveur)
    },
}

---@class vAvA.MagicSheet
---@field characterId integer
---@field isMage boolean
---@field sigil string
---@field spells table<string, { xp: integer }>
---@field sigils { sigil: string, name: string }[]
---@field selectedSpell string|nil
---@field discoveredCombos string[]
---@field lightColor string|nil
---@field register integer|nil
---@field scrambledAt integer|nil
---@field dirty boolean

---@type table<integer, vAvA.MagicSheet>
local loaded = {}
---@type table<string, integer>  sigil → source du joueur en jeu
local bySigil = {}
---@type table<integer, integer>  joueur → personnage dont la fiche se charge (lecture du sigil en cours)
local loading = {}

---@param value any
---@return integer|nil
local function integer(value)
    if type(value) ~= 'number' then return nil end
    return tointeger(floor(value))
end

--- Fiche relue (base JSON) remise au propre : champs inconnus ou abîmés écartés.
---@param stored table|nil
---@return table
local function sanitize(stored)
    local clean = { isMage = false, spells = {}, sigils = {}, discoveredCombos = {} }
    if type(stored) ~= 'table' then return clean end
    clean.isMage = stored.isMage == true
    if type(stored.sigil) == 'string' and #stored.sigil == sigilCfg.length then clean.sigil = stored.sigil end
    if type(stored.spells) == 'table' then
        for name, entry in pairs(stored.spells) do
            local xp = type(entry) == 'table' and integer(entry.xp)
            if type(name) == 'string' and xp then clean.spells[name] = { xp = xp < 0 and 0 or (xp > MAX_XP and MAX_XP or xp) } end
        end
    end
    if type(stored.sigils) == 'table' then
        for _, contact in ipairs(stored.sigils) do
            if #clean.sigils >= SIGILS_MAX then break end
            if type(contact) == 'table' and type(contact.sigil) == 'string' and type(contact.name) == 'string' then
                clean.sigils[#clean.sigils + 1] = { sigil = contact.sigil, name = contact.name }
            end
        end
    end
    if type(stored.selectedSpell) == 'string' and clean.spells[stored.selectedSpell] then clean.selectedSpell = stored.selectedSpell end
    if type(stored.discoveredCombos) == 'table' then
        for _, combo in ipairs(stored.discoveredCombos) do
            if #clean.discoveredCombos >= COMBOS_MAX then break end
            if type(combo) == 'string' then clean.discoveredCombos[#clean.discoveredCombos + 1] = combo end
        end
    end
    if type(stored.lightColor) == 'string' then clean.lightColor = stored.lightColor end
    clean.register = integer(stored.register)
    clean.scrambledAt = integer(stored.scrambledAt)
    return clean
end

---@return string
local function randomSigil()
    local alphabet = sigilCfg.alphabet
    local size = #alphabet
    local chars = {}
    for i = 1, sigilCfg.length do
        local index = random(1, size)
        chars[i] = sub(alphabet, index, index)
    end
    return concat(chars)
end

--- Sigil du personnage selon la base ; tiré au hasard (et enregistré) s'il n'en a pas. nil si la base échoue.
---@param characterId integer
---@param preferred string|nil  sigil gardé dans la fiche, repris s'il est libre
---@return string|nil
local function ensureSigil(characterId, preferred)
    local current, err = bridge.db.scalar(SELECT_SIGIL, { characterId })
    if err then return nil end
    if type(current) == 'string' then return current end
    for attempt = 1, sigilCfg.retries do
        local candidate = (attempt == 1 and preferred) or randomSigil()
        local _, insertErr = bridge.db.insert(INSERT_SIGIL, { candidate, characterId })
        if not insertErr then return candidate end
    end
    VavaMagic.log.error('aucun sigil libre pour le personnage %d', characterId)
    return nil
end

--- Charge la fiche d'un personnage qui arrive. Bloque le thread appelant (base de données).
---@param src integer
---@param characterId integer
---@return boolean ok
---@return string|nil code  'left' : le joueur est parti pendant la lecture
function sheets.load(src, characterId)
    loading[src] = characterId
    local sheet = sanitize(bridge.LoadSheet(characterId))
    local sigil = ensureSigil(characterId, sheet.sigil)
    -- parti pendant la lecture (déconnexion, retour à la sélection) : son départ est déjà passé, rien n'est gardé
    if loading[src] ~= characterId then return false, 'left' end
    loading[src] = nil
    if not sigil then return false end
    local changed = sheet.sigil ~= sigil
    sheet.sigil = sigil
    sheet.characterId = characterId
    sheet.dirty = changed
    loaded[src] = sheet
    bySigil[sigil] = src
    if changed then sheets.save(src) end
    return true
end

---@param src integer
---@return vAvA.MagicSheet|nil
function sheets.get(src)
    return loaded[src]
end

--- Source du joueur en jeu qui porte ce sigil, ou nil.
---@param sigil string
---@return integer|nil
function sheets.sourceOf(sigil)
    return bySigil[sigil]
end

--- Joueurs dont la fiche est chargée.
---@return table<integer, vAvA.MagicSheet>
function sheets.all()
    return loaded
end

---@param src integer
---@param spell string
---@return integer|nil xp  nil si le sort n'est pas connu
function sheets.xp(src, spell)
    local sheet = loaded[src]
    local entry = sheet and sheet.spells[spell]
    return entry and entry.xp or nil
end

---@param src integer
---@param spell string
---@return integer|nil level
function sheets.level(src, spell)
    local xp = sheets.xp(src, spell)
    return xp and progression.levelOf(xp) or nil
end

---@param sheet vAvA.MagicSheet
---@return integer
function sheets.sigilLimit(sheet)
    local entry = sheet.spells[sigilCfg.spell]
    return progression.sigilLimit(sheet.isMage, entry and entry.xp or nil)
end

--- Rang du contact qui porte ce sigil dans la liste du personnage, ou nil.
---@param sheet vAvA.MagicSheet
---@param sigil string
---@return integer|nil
function sheets.contactIndex(sheet, sigil)
    for index, contact in ipairs(sheet.sigils) do
        if contact.sigil == sigil then return index end
    end
    return nil
end

--- Vue de la fiche pour son joueur (sans aucun sigil) : { isMage, spells = { { name, xp, level } }, selected,
--- combos, sigilCount, sigilLimit, lightColor }.
---@param src integer
---@return table|nil
function sheets.view(src)
    local sheet = loaded[src]
    if not sheet then return nil end
    local spells = {}
    for name, entry in pairs(sheet.spells) do
        spells[#spells + 1] = { name = name, xp = entry.xp, level = progression.levelOf(entry.xp) }
    end
    local combos = {}
    for i, combo in ipairs(sheet.discoveredCombos) do combos[i] = combo end
    return {
        isMage = sheet.isMage, spells = spells, selected = sheet.selectedSpell or '', combos = combos,
        sigilCount = #sheet.sigils, sigilLimit = sheets.sigilLimit(sheet), lightColor = sheet.lightColor or '',
    }
end

--- Envoie la vue de la fiche à son joueur.
---@param src integer
function sheets.push(src)
    local view = sheets.view(src)
    if view then TriggerClientEvent(EVENTS.SHEET, src, view) end
end

--- La fiche a changé : écrite au prochain passage ; `push` renvoie aussi sa vue au joueur.
---@param src integer
---@param push? boolean
function sheets.touch(src, push)
    local sheet = loaded[src]
    if not sheet then return end
    sheet.dirty = true
    if push then sheets.push(src) end
end

--- Valeur enregistrée de la fiche (sans les champs de travail).
---@param sheet vAvA.MagicSheet
---@return table
local function stored(sheet)
    local spells, sigils = {}, {}
    for name, entry in pairs(sheet.spells) do spells[name] = { xp = entry.xp } end
    for i, contact in ipairs(sheet.sigils) do sigils[i] = { sigil = contact.sigil, name = contact.name } end
    local combos = {}
    for i, combo in ipairs(sheet.discoveredCombos) do combos[i] = combo end
    return {
        isMage = sheet.isMage, sigil = sheet.sigil, spells = spells, sigils = sigils,
        selectedSpell = sheet.selectedSpell, discoveredCombos = combos,
        lightColor = sheet.lightColor, register = sheet.register, scrambledAt = sheet.scrambledAt,
    }
end

--- Écrit la fiche dans le personnage si elle a changé.
---@param src integer
function sheets.save(src)
    local sheet = loaded[src]
    if not sheet or not sheet.dirty then return end
    local ok, err = bridge.SaveSheet(sheet.characterId, stored(sheet))
    if ok then
        sheet.dirty = false
    else
        VavaMagic.log.error('fiche du personnage %d non écrite : %s', sheet.characterId, tostring(err))
    end
end

--- Départ du personnage : fiche écrite, puis oubliée.
---@param src integer
function sheets.unload(src)
    loading[src] = nil
    local sheet = loaded[src]
    if not sheet then return end
    sheets.save(src)
    if bySigil[sheet.sigil] == src then bySigil[sheet.sigil] = nil end
    loaded[src] = nil
end

--- Nouveau sigil (brouillage) : enregistré en base, puis dans la fiche ; l'ancien n'existe plus. Bloque le thread.
---@param src integer
---@return boolean ok
function sheets.scramble(src)
    local sheet = loaded[src]
    if not sheet then return false end
    for _ = 1, sigilCfg.retries do
        local candidate = randomSigil()
        local _, err = bridge.db.update(UPDATE_SIGIL, { candidate, sheet.characterId })
        if not err then
            if bySigil[sheet.sigil] == src then bySigil[sheet.sigil] = nil end
            sheet.sigil = candidate
            bySigil[candidate] = src
            sheets.touch(src)
            return true
        end
    end
    return false
end

--- Sort prêt dans les mains (choisi dans la roue) ; '' : aucun. Le sort doit être connu.
---@param src integer
---@param name string
---@return boolean ok
---@return string|nil code
function sheets.select(src, name)
    local sheet = loaded[src]
    if not sheet then return false, 'not_ready' end
    if name == '' then
        if sheet.selectedSpell ~= nil then
            sheet.selectedSpell = nil
            sheets.touch(src)
        end
        return true
    end
    if not sheet.isMage then return false, 'not_mage' end
    if not sheet.spells[name] or not VavaMagic.spells.get(name) then return false, 'unknown_spell' end
    if sheet.selectedSpell ~= name then
        sheet.selectedSpell = name
        sheets.touch(src)
    end
    return true
end

--- Sort oublié : il n'est plus prêt dans les mains.
---@param sheet vAvA.MagicSheet
---@param name string
function sheets.forgetSpell(sheet, name)
    sheet.spells[name] = nil
    if sheet.selectedSpell == name then sheet.selectedSpell = nil end
end

--- Combinaison déclenchée pour la première fois : notée pour le grimoire. Renvoie vrai si elle est nouvelle.
---@param src integer
---@param combo string
---@return boolean
function sheets.discover(src, combo)
    local sheet = loaded[src]
    if not sheet then return false end
    for _, known in ipairs(sheet.discoveredCombos) do
        if known == combo then return false end
    end
    if #sheet.discoveredCombos >= COMBOS_MAX then return false end
    sheet.discoveredCombos[#sheet.discoveredCombos + 1] = combo
    sheets.touch(src, true)
    return true
end

--- Personnage supprimé : son sigil disparaît du royaume.
---@param characterId integer
function sheets.forgetCharacter(characterId)
    bridge.db.update(DELETE_SIGIL, { characterId })
end

--- Écriture régulière des fiches modifiées. Appelé pendant le setup du module.
function sheets.start()
    local function flush()
        for src in pairs(loaded) do sheets.save(src) end
        SetTimeout(cfg.persistence.flushMs, flush)
    end
    SetTimeout(cfg.persistence.flushMs, flush)
end

sheets.integer = integer
