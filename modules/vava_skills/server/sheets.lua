--[[
    vava_skills/server/sheets.lua
    Rôle : fiches de compétences des personnages en jeu, source de vérité pendant la partie : niveaux, XP, modes,
           Renommée, dernière pratique ; recettes transmises connues ; leçons en cours ; mentorats en cours (comme maître
           et comme apprenti). Chargées à l'arrivée du personnage (avant l'apparition), écrites par lots toutes les
           `persistence.flushMs` si elles ont changé (un changement pendant l'écriture reste à écrire), et aussitôt au
           départ. Vues pour le client (une compétence, la fiche entière).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/registries.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local floor = math.floor
local CreateThread, Wait = CreateThread, Wait
local time = os.time

local bridge = VavaSkills.bridge
local registries = VavaSkills.registries
local progression = VavaSkills.progression
local cfg = VavaSkills.config
local MODES = VavaSkills.MODES

local SELECT_SKILLS_SQL = 'SELECT `skill`, `level`, `xp`, `mode`, `renown`, `renown_day`, `renown_day_gained`, `practiced_at` FROM `vava_skills_skills` WHERE `character_id` = ?'
local SELECT_RECIPES_SQL = 'SELECT `recipe`, `learned_at`, `source`, `taught_by` FROM `vava_skills_recipes` WHERE `character_id` = ?'
local SELECT_LESSONS_SQL = 'SELECT `recipe`, COUNT(*) AS `count`, MAX(`at`) AS `last_at` FROM `vava_skills_lessons` WHERE `student_id` = ? GROUP BY `recipe`'
local SELECT_MENTORSHIPS_SQL = 'SELECT `id`, `skill`, `master_id`, `apprentice_id`, `started_at`, `xp_granted`, `renown_granted` '
    .. 'FROM `vava_skills_mentorships` WHERE `ended_at` IS NULL AND (`master_id` = ? OR `apprentice_id` = ?)'
local SELECT_PAIR_RENOWN_SQL = 'SELECT COALESCE(SUM(`renown_granted`), 0) FROM `vava_skills_mentorships` WHERE `master_id` = ? AND `apprentice_id` = ? AND `skill` = ?'
local UPSERT_SKILL_SQL = 'INSERT INTO `vava_skills_skills` (`character_id`, `skill`, `level`, `xp`, `mode`, `renown`, `renown_day`, `renown_day_gained`, `practiced_at`, `updated_at`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `level` = VALUES(`level`), `xp` = VALUES(`xp`), `mode` = VALUES(`mode`), '
    .. '`renown` = VALUES(`renown`), `renown_day` = VALUES(`renown_day`), `renown_day_gained` = VALUES(`renown_day_gained`), '
    .. '`practiced_at` = VALUES(`practiced_at`), `updated_at` = VALUES(`updated_at`)'

local sheets = {}
VavaSkills.sheets = sheets

---@class vAvA.SkillEntry
---@field level integer
---@field xp integer             XP dans le niveau courant
---@field mode 'up'|'keep'|'down'
---@field renown integer
---@field renownDay integer      jour UTC du dernier gain de Renommée
---@field renownDayGained integer
---@field practicedAt integer    secondes, 0 jamais
---@field dirty boolean|'writing' true : à écrire ; 'writing' : écriture en cours (un changement pendant l'attente → true)

---@class vAvA.Mentorship
---@field id integer
---@field skill string
---@field masterId integer
---@field apprenticeId integer
---@field startedAt integer
---@field xpGranted integer
---@field renownGranted integer
---@field pairRenown integer     Renommée déjà rapportée par cet apprenti à ce maître (tous mentorats confondus)
---@field dirty boolean|'writing' compteurs : true à écrire, 'writing' écriture en cours (mentoring.lua)

---@class vAvA.SkillSheet
---@field characterId integer
---@field source integer
---@field accountId integer
---@field name string
---@field skills table<string, vAvA.SkillEntry>
---@field recipes table<string, { learnedAt: integer, source: string, taughtBy: integer|nil }>
---@field lessons table<string, { count: integer, lastAt: integer }>   apprentissages en cours (recette → leçons reçues)
---@field mentors table<string, vAvA.Mentorship>                        compétence → mentorat où je suis apprenti
---@field apprentices table<string, table<integer, vAvA.Mentorship>>   compétence → apprenti → mentorat où je suis maître
---@field names table<integer, string>                                 noms des personnages liés (maîtres, apprentis, professeurs)

---@type table<integer, vAvA.SkillSheet>
local bySource = {}
---@type table<integer, vAvA.SkillSheet>
local byCharacter = {}
-- mentorats en cours partagés entre les deux fiches : id → enregistrement (une seule copie, dirty commun)
---@type table<integer, vAvA.Mentorship>
local mentorships = {}
-- marque d'une compétence en cours d'écriture (voir `collect`)
local WRITING = 'writing'

local integer = bridge.Integer

--- Jour UTC (jours écoulés depuis l'époque) d'un instant.
---@param seconds integer
---@return integer
function sheets.dayOf(seconds)
    return floor(seconds / 86400)
end

---@return vAvA.SkillEntry
local function newEntry()
    return { level = 0, xp = 0, mode = 'keep', renown = 0, renownDay = 0, renownDayGained = 0, practicedAt = 0, dirty = false }
end

---@param row table
---@return vAvA.Mentorship
local function toMentorship(row)
    return {
        id = integer(row.id, 0), skill = row.skill, masterId = integer(row.master_id, 0), apprenticeId = integer(row.apprentice_id, 0),
        startedAt = integer(row.started_at, 0), xpGranted = integer(row.xp_granted, 0), renownGranted = integer(row.renown_granted, 0),
        pairRenown = 0, dirty = false,
    }
end

--- Rattache un mentorat à une fiche (côté maître ou apprenti selon le personnage de la fiche).
---@param sheet vAvA.SkillSheet
---@param mentorship vAvA.Mentorship
function sheets.attachMentorship(sheet, mentorship)
    mentorships[mentorship.id] = mentorship
    if mentorship.apprenticeId == sheet.characterId then
        sheet.mentors[mentorship.skill] = mentorship
    elseif mentorship.masterId == sheet.characterId then
        local list = sheet.apprentices[mentorship.skill]
        if not list then
            list = {}
            sheet.apprentices[mentorship.skill] = list
        end
        list[mentorship.apprenticeId] = mentorship
    end
end

--- Détache un mentorat terminé de toutes les fiches chargées.
---@param mentorship vAvA.Mentorship
function sheets.detachMentorship(mentorship)
    mentorships[mentorship.id] = nil
    local apprentice = byCharacter[mentorship.apprenticeId]
    if apprentice and apprentice.mentors[mentorship.skill] == mentorship then apprentice.mentors[mentorship.skill] = nil end
    local master = byCharacter[mentorship.masterId]
    local list = master and master.apprentices[mentorship.skill]
    if list then list[mentorship.apprenticeId] = nil end
end

--- Mentorat en cours par son identifiant (fiches chargées seulement).
---@param id integer
---@return vAvA.Mentorship|nil
function sheets.mentorship(id)
    return mentorships[id]
end

--- Charge la fiche d'un personnage qui arrive. Bloque le thread appelant (base de données).
---@param src integer
---@param character table  { id, accountId, firstName, lastName }
---@return vAvA.SkillSheet|nil
function sheets.load(src, character)
    local characterId = character.id
    local sheet = {
        characterId = characterId, source = src, accountId = character.accountId,
        name = character.firstName .. ' ' .. character.lastName,
        skills = {}, recipes = {}, lessons = {}, mentors = {}, apprentices = {}, names = {},
    }
    local rows, err = bridge.db.query(SELECT_SKILLS_SQL, { characterId })
    if err then return nil end
    for _, row in ipairs(rows) do
        local entry = newEntry()
        entry.level = progression.clampLevel(integer(row.level, 0))
        entry.xp = integer(row.xp, 0)
        entry.mode = MODES[row.mode] and row.mode or 'keep'
        entry.renown = integer(row.renown, 0)
        entry.renownDay = integer(row.renown_day, 0)
        entry.renownDayGained = integer(row.renown_day_gained, 0)
        entry.practicedAt = integer(row.practiced_at, 0)
        sheet.skills[row.skill] = entry
    end
    rows, err = bridge.db.query(SELECT_RECIPES_SQL, { characterId })
    if err then return nil end
    local linked = {}
    for _, row in ipairs(rows) do
        local taughtBy = row.taught_by ~= nil and integer(row.taught_by, 0) or nil
        if taughtBy == 0 then taughtBy = nil end
        sheet.recipes[row.recipe] = { learnedAt = integer(row.learned_at, 0), source = row.source, taughtBy = taughtBy }
        if taughtBy then linked[taughtBy] = true end
    end
    rows, err = bridge.db.query(SELECT_LESSONS_SQL, { characterId })
    if err then return nil end
    for _, row in ipairs(rows) do
        if not sheet.recipes[row.recipe] then
            sheet.lessons[row.recipe] = { count = integer(row.count, 0), lastAt = integer(row.last_at, 0) }
        end
    end
    rows, err = bridge.db.query(SELECT_MENTORSHIPS_SQL, { characterId, characterId })
    if err then return nil end
    for _, row in ipairs(rows) do
        local id = integer(row.id, 0)
        -- l'autre partie est peut-être déjà en jeu : une seule copie du mentorat
        local mentorship = mentorships[id]
        if not mentorship then
            mentorship = toMentorship(row)
            local pair = bridge.db.scalar(SELECT_PAIR_RENOWN_SQL, { mentorship.masterId, mentorship.apprenticeId, mentorship.skill })
            mentorship.pairRenown = integer(pair, 0)
        end
        sheets.attachMentorship(sheet, mentorship)
        linked[mentorship.masterId == characterId and mentorship.apprenticeId or mentorship.masterId] = true
    end
    local ids = {}
    for id in pairs(linked) do ids[#ids + 1] = id end
    sheet.names = bridge.NamesOf(ids)
    bySource[src] = sheet
    byCharacter[characterId] = sheet
    return sheet
end

---@param src integer
---@return vAvA.SkillSheet|nil
function sheets.get(src)
    return bySource[src]
end

---@param characterId integer
---@return vAvA.SkillSheet|nil
function sheets.byCharacter(characterId)
    return byCharacter[characterId]
end

---@return table<integer, vAvA.SkillSheet>
function sheets.all()
    return bySource
end

--- Entrée d'une compétence ; créée (niveau 0, mode keep) si `create`.
---@param sheet vAvA.SkillSheet
---@param skill string
---@param create? boolean
---@return vAvA.SkillEntry|nil
function sheets.entry(sheet, skill, create)
    local entry = sheet.skills[skill]
    if not entry and create then
        entry = newEntry()
        sheet.skills[skill] = entry
    end
    return entry
end

--- Niveau d'une compétence (0 si jamais pratiquée).
---@param sheet vAvA.SkillSheet
---@param skill string
---@return integer
function sheets.level(sheet, skill)
    local entry = sheet.skills[skill]
    return entry and entry.level or 0
end

--- Marque une compétence à écrire.
---@param entry vAvA.SkillEntry
function sheets.touch(entry)
    entry.dirty = true
end

--- Nom d'un personnage lié à la fiche (relu en base s'il n'est pas connu). Bloque le thread si une lecture est faite.
---@param sheet vAvA.SkillSheet
---@param characterId integer
---@return string
function sheets.nameOf(sheet, characterId)
    local online = byCharacter[characterId]
    if online then return online.name end
    local name = sheet.names[characterId]
    if name then return name end
    name = bridge.NamesOf({ characterId })[characterId] or ('Personnage n° ' .. tostring(characterId))
    sheet.names[characterId] = name
    return name
end

-- Vues pour le client ----------------------------------------------------------------------------------------------

---@param sheet vAvA.SkillSheet
---@return { used: integer, total: integer }
function sheets.budget(sheet)
    return { used = progression.budgetUsed(sheet.skills), total = cfg.levels.budget }
end

---@param sheet vAvA.SkillSheet
---@param mentorship vAvA.Mentorship
---@param otherId integer
---@return table
local function mentorshipView(sheet, mentorship, otherId)
    return {
        mentorshipId = mentorship.id, characterId = otherId, name = sheets.nameOf(sheet, otherId),
        since = mentorship.startedAt, online = byCharacter[otherId] ~= nil,
    }
end

--- Vue d'une compétence : niveau, XP, rang, mode, Renommée, pénurie, mentorat.
---@param sheet vAvA.SkillSheet
---@param skill string
---@return table|nil
function sheets.skillView(sheet, skill)
    local def = registries.skill(skill)
    if not def then return nil end
    local entry = sheet.skills[skill] or newEntry()
    local rank = progression.rankOf(entry.level)
    local mentoring = VavaSkills.mentoring
    local apprentices = {}
    for apprenticeId, mentorship in pairs(sheet.apprentices[skill] or {}) do
        apprentices[#apprentices + 1] = mentorshipView(sheet, mentorship, apprenticeId)
    end
    local mentor = sheet.mentors[skill]
    return {
        id = skill, label = def.label, category = def.category,
        level = entry.level, xp = entry.xp, xpToNext = progression.xpToNext(entry.level),
        rank = { name = rank.name, label = rank.label }, mode = entry.mode,
        renown = entry.renown, practicedAt = entry.practicedAt,
        shortage = VavaSkills.shortages.multiplier(skill),
        mentoredOnly = def.mentoredOnly,
        canMentor = mentoring.canMentor(sheet, skill),
        mentor = mentor and mentorshipView(sheet, mentor, mentor.masterId) or nil,
        apprentices = apprentices,
    }
end

--- Fiche complète pour le livre des compétences.
---@param sheet vAvA.SkillSheet
---@return table
function sheets.view(sheet)
    local skills = {}
    for _, def in ipairs(registries.skills()) do skills[#skills + 1] = sheets.skillView(sheet, def.id) end
    local recipes = {}
    for recipe, known in pairs(sheet.recipes) do
        local def = registries.recipe(recipe)
        recipes[#recipes + 1] = {
            id = recipe, label = def and def.label or recipe, skill = def and def.skill or '',
            learnedAt = known.learnedAt, source = known.source,
            taughtBy = known.taughtBy and { characterId = known.taughtBy, name = sheets.nameOf(sheet, known.taughtBy) } or nil,
        }
    end
    local ranks = {}
    for index, rank in ipairs(cfg.ranks) do ranks[index] = { name = rank.name, label = rank.label, min = rank.min } end
    local mentoring = cfg.mentoring
    return {
        character = { id = sheet.characterId, name = sheet.name, playSeconds = bridge.GetPlaySeconds(sheet.source) },
        rules = {
            commonKnowledge = cfg.levels.commonKnowledge, budget = cfg.levels.budget, maxLevel = cfg.levels.max, ranks = ranks,
            lessonsRequired = cfg.lessons.required,
            mentoring = { minRank = mentoring.minRank, maxApprentices = mentoring.maxApprentices, bonus = mentoring.bonus },
        },
        budget = sheets.budget(sheet),
        categories = registries.categories(),
        skills = skills,
        recipes = recipes,
        lessons = VavaSkills.lessons.inProgress(sheet),
        proposals = VavaSkills.mentoring.proposalsFor(sheet.source),
        shortages = VavaSkills.shortages.list(),
        now = time(),
    }
end

-- Persistance -----------------------------------------------------------------------------------------------------

--- Requêtes des compétences à écrire, marquées « en cours d'écriture » : l'écriture cède la main, et un gain pendant
--- l'attente les marque de nouveau à écrire au lieu d'être effacé par `clean`.
---@param sheet vAvA.SkillSheet
---@param queries table[]
---@param now integer
local function collect(sheet, queries, now)
    for skill, entry in pairs(sheet.skills) do
        if entry.dirty then
            entry.dirty = WRITING
            queries[#queries + 1] = { query = UPSERT_SKILL_SQL, values = {
                sheet.characterId, skill, entry.level, entry.xp, entry.mode, entry.renown, entry.renownDay, entry.renownDayGained,
                entry.practicedAt, now,
            } }
        end
    end
end

--- Écriture réussie : seules les compétences restées telles qu'écrites sont propres (en échec, elles restent à écrire).
---@param sheet vAvA.SkillSheet
local function clean(sheet)
    for _, entry in pairs(sheet.skills) do
        if entry.dirty == WRITING then entry.dirty = false end
    end
end

--- Écrit les fiches modifiées (et les mentorats modifiés) en une transaction. Bloque le thread courant.
---@param only? vAvA.SkillSheet  une seule fiche (départ du personnage)
---@return boolean ok
function sheets.flush(only)
    local queries = {}
    local now = time()
    local targets = only and { only } or bySource
    for _, sheet in pairs(targets) do collect(sheet, queries, now) end
    VavaSkills.mentoring.collectQueries(queries, only)
    if #queries == 0 then return true end
    local ok, err = bridge.db.transaction(queries)
    if not ok then
        VavaSkills.log.error('écriture des compétences en échec (%d requête(s)), nouvel essai au prochain passage : %s', #queries, tostring(err))
        return false
    end
    for _, sheet in pairs(targets) do clean(sheet) end
    VavaSkills.mentoring.markClean(only)
    return true
end

--- Départ du personnage : fiche écrite, puis oubliée (ses mentorats restent connus si l'autre partie est en jeu).
---@param src integer
function sheets.unload(src)
    local sheet = bySource[src]
    if not sheet then return end
    sheets.flush(sheet)
    bySource[src] = nil
    if byCharacter[sheet.characterId] == sheet then byCharacter[sheet.characterId] = nil end
    for id, mentorship in pairs(mentorships) do
        local masterOnline = byCharacter[mentorship.masterId] ~= nil
        local apprenticeOnline = byCharacter[mentorship.apprenticeId] ~= nil
        if not masterOnline and not apprenticeOnline then mentorships[id] = nil end
    end
end

--- Écriture régulière. Appelé pendant le setup du module.
function sheets.start()
    CreateThread(function()
        -- boucle lente justifiée : au plus une transaction toutes les flushMs, rien si aucune fiche n'a changé
        while true do
            Wait(cfg.persistence.flushMs)
            sheets.flush()
        end
    end)
end

sheets.newEntry = newEntry
sheets.toMentorship = toMentorship
