--[[
    vava_skills/server/lessons.lua
    Rôle : savoirs transmis. Une recette libre se connaît par le niveau ; une recette `transmission` s'apprend par
           leçons (celui qui la connaît la réalise en présence de l'élève, qui a le niveau requis), au nombre et au
           rythme de la config, ou en réunissant ses fragments (savoirs perdus), ou de la main d'un fondateur. Chaque
           apprentissage garde son professeur : la lignée d'un savoir se remonte jusqu'au fondateur. Hook
           `vava_skills:recipeLearned` (after) ; évènements et notifications.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/registries.lua,
                  server/sheets.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local mathType = math.type
local format = string.format
local TriggerClientEvent = TriggerClientEvent
local time = os.time

local core = VavaSkills.core
local bridge = VavaSkills.bridge
local journal = VavaSkills.journal
local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local cfg = VavaSkills.config
local lessonCfg, mentorCfg, messages = cfg.lessons, cfg.mentoring, cfg.messages
local EVENTS = VavaSkills.EVENTS

local HOOK_LEARNED = 'vava_skills:recipeLearned'
local MAX_LINEAGE = 64

local INSERT_RECIPE_SQL = 'INSERT IGNORE INTO `vava_skills_recipes` (`character_id`, `recipe`, `learned_at`, `source`, `taught_by`) VALUES (?, ?, ?, ?, ?)'
local SELECT_RECIPE_SQL = 'SELECT `learned_at`, `source`, `taught_by` FROM `vava_skills_recipes` WHERE `character_id` = ? AND `recipe` = ?'
local INSERT_LESSON_SQL = 'INSERT INTO `vava_skills_lessons` (`recipe`, `student_id`, `teacher_id`, `at`, `number`) VALUES (?, ?, ?, ?, ?)'
local INSERT_FRAGMENT_SQL = 'INSERT IGNORE INTO `vava_skills_fragments` (`character_id`, `recipe`, `fragment`, `found_at`) VALUES (?, ?, ?, ?)'
local SELECT_FRAGMENTS_SQL = 'SELECT `fragment` FROM `vava_skills_fragments` WHERE `character_id` = ? AND `recipe` = ?'

local lessons = {}
VavaSkills.lessons = lessons

--- Vrai si le personnage de la fiche connaît la recette : par le niveau (recette libre) ou par apprentissage.
---@param sheet vAvA.SkillSheet
---@param recipe any
---@return boolean
function lessons.knows(sheet, recipe)
    local def = registries.recipe(recipe)
    if not def then return false end
    if not def.transmission then return sheets.level(sheet, def.skill) >= def.level end
    return sheet.recipes[def.id] ~= nil
end

--- Apprentissages en cours de la fiche : { recipe, label, skill, count, required, lastAt, nextAllowedAt }.
---@param sheet vAvA.SkillSheet
---@return table[]
function lessons.inProgress(sheet)
    local list = {}
    for recipe, progress in pairs(sheet.lessons) do
        local def = registries.recipe(recipe)
        if def and not sheet.recipes[recipe] then
            list[#list + 1] = {
                recipe = recipe, label = def.label, skill = def.skill, count = progress.count, required = lessonCfg.required,
                lastAt = progress.lastAt, nextAllowedAt = progress.lastAt + lessonCfg.minIntervalMs // 1000,
            }
        end
    end
    return list
end

--- Inscrit un savoir au personnage (en jeu ou non). Bloque le thread courant.
---@param characterId integer
---@param def vAvA.RecipeDefinition
---@param source 'lesson'|'founder'|'fragments'|'admin'
---@param taughtBy integer|nil
---@param actor { characterId?: integer, accountId?: integer }
---@return boolean ok
---@return string|nil code  already_known | db_error
function lessons.learn(characterId, def, source, taughtBy, actor)
    local sheet = sheets.byCharacter(characterId)
    if sheet and sheet.recipes[def.id] then return false, 'already_known' end
    local learnedAt = time()
    local affected, err = bridge.db.update(INSERT_RECIPE_SQL, { characterId, def.id, learnedAt, source, taughtBy })
    if err then return false, 'db_error' end
    if affected == 0 then return false, 'already_known' end
    if sheet then
        sheet.recipes[def.id] = { learnedAt = learnedAt, source = source, taughtBy = taughtBy }
        sheet.lessons[def.id] = nil
        local teacher = taughtBy and { characterId = taughtBy, name = sheets.nameOf(sheet, taughtBy) } or nil
        TriggerClientEvent(EVENTS.RECIPE, sheet.source, { recipe = def.id, label = def.label, skill = def.skill, source = source, taughtBy = teacher })
        bridge.Notify(sheet.source, format(messages.recipeLearned, def.label), 'info')
    end
    journal.write('recipe_learned', { actorId = actor.characterId, accountId = actor.accountId, targetId = characterId, recipe = def.id, details = { source = source, taughtBy = taughtBy } })
    core.hooks.runAfter(HOOK_LEARNED, { characterId = characterId, recipe = def.id, skill = def.skill, source = source, taughtBy = taughtBy })
    return true
end

--- Une leçon : le professeur vient de réaliser la recette devant l'élève (appelé par l'artisanat). Bloque le thread.
---@param teacherSrc integer
---@param studentSrc integer
---@param recipe any
---@return boolean ok
---@return string|table result  code, ou { count, required, learned }
function lessons.recordLesson(teacherSrc, studentSrc, recipe)
    local teacher, student = sheets.get(teacherSrc), sheets.get(studentSrc)
    if not teacher then return false, 'no_character' end
    if not student then return false, 'no_student' end
    local def = registries.recipe(recipe)
    if not def then return false, 'unknown_recipe' end
    if not def.transmission then return false, 'not_transmitted' end
    if teacher == student or teacher.accountId == student.accountId then return false, 'same_account' end
    if not lessons.knows(teacher, def.id) then return false, 'teacher_unknown' end
    if bridge.GetPlaySeconds(teacherSrc) < mentorCfg.minTeachPlaySeconds then return false, 'too_young' end
    if student.recipes[def.id] then return false, 'already_known' end
    if sheets.level(student, def.skill) < def.level then return false, 'student_level' end
    if not bridge.Within(teacherSrc, studentSrc, lessonCfg.radius) then return false, 'too_far' end
    local previous = student.lessons[def.id]
    local progress = previous or { count = 0, lastAt = 0 }
    local now = time()
    if progress.count > 0 and now - progress.lastAt < lessonCfg.minIntervalMs // 1000 then return false, 'too_soon' end

    local number = progress.count + 1
    -- tenue avant l'écriture (la base fait attendre) : une leçon simultanée d'un autre professeur trouve le délai en cours
    local reserved = { count = number, lastAt = now }
    student.lessons[def.id] = reserved
    local _, err = bridge.db.insert(INSERT_LESSON_SQL, { def.id, student.characterId, teacher.characterId, now, number })
    if err then
        if student.lessons[def.id] == reserved then student.lessons[def.id] = previous end
        return false, 'db_error'
    end
    student.names[teacher.characterId], teacher.names[student.characterId] = teacher.name, student.name
    journal.write('lesson', { actorId = teacher.characterId, targetId = student.characterId, recipe = def.id, details = { number = number, required = lessonCfg.required } })
    TriggerClientEvent(EVENTS.LESSON, teacherSrc, { recipe = def.id, label = def.label, count = number, required = lessonCfg.required, role = 'teacher', other = { name = student.name } })
    TriggerClientEvent(EVENTS.LESSON, studentSrc, { recipe = def.id, label = def.label, count = number, required = lessonCfg.required, role = 'student', other = { name = teacher.name } })
    bridge.Notify(teacherSrc, format(messages.lessonGiven, student.name, def.label, number, lessonCfg.required), 'info')
    bridge.Notify(studentSrc, format(messages.lessonReceived, teacher.name, def.label, number, lessonCfg.required), 'info')

    local learned = false
    if number >= lessonCfg.required then
        learned = lessons.learn(student.characterId, def, 'lesson', teacher.characterId, { characterId = teacher.characterId }) == true
    end
    return true, { count = number, required = lessonCfg.required, learned = learned }
end

--- Un fragment de savoir perdu est réuni (objet consommé par le module qui le déclare). Bloque le thread.
---@param src integer
---@param recipe any
---@param fragment any
---@return boolean ok
---@return string|table result  code, ou { found, total, learned }
function lessons.addFragment(src, recipe, fragment)
    local sheet = sheets.get(src)
    if not sheet then return false, 'no_character' end
    local def = registries.recipe(recipe)
    if not def or not def.transmission then return false, 'unknown_recipe' end
    if type(def.fragments) ~= 'table' then return false, 'no_fragments' end
    local known = false
    for _, name in ipairs(def.fragments) do
        if name == fragment then known = true end
    end
    if not known then return false, 'unknown_fragment' end
    if sheet.recipes[def.id] then return false, 'already_known' end
    local _, err = bridge.db.update(INSERT_FRAGMENT_SQL, { sheet.characterId, def.id, fragment, time() })
    if err then return false, 'db_error' end
    local rows
    rows, err = bridge.db.query(SELECT_FRAGMENTS_SQL, { sheet.characterId, def.id })
    if err then return false, 'db_error' end
    local found = {}
    for _, row in ipairs(rows) do found[row.fragment] = true end
    local count = 0
    for _, name in ipairs(def.fragments) do
        if found[name] then count = count + 1 end
    end
    bridge.Notify(src, format(messages.fragmentFound, def.label, count, #def.fragments), 'info')
    local learned = false
    if count >= #def.fragments then
        learned = lessons.learn(sheet.characterId, def, 'fragments', nil, { characterId = sheet.characterId }) == true
    end
    return true, { found = count, total = #def.fragments, learned = learned }
end

--- Lignée d'un savoir : du personnage à son professeur, et ainsi de suite jusqu'au fondateur (ou à une source sans
--- professeur). Bloque le thread courant (une lecture par maillon).
---@param characterId integer
---@param recipe any
---@return table|nil result  { recipe, label, chain = { { characterId, name, learnedAt, source } } }
---@return string|nil code
function lessons.lineage(characterId, recipe)
    local def = registries.recipe(recipe)
    if not def then return nil, 'unknown_recipe' end
    local chain, visited = {}, {}
    local current = characterId
    while current and not visited[current] and #chain < MAX_LINEAGE do
        visited[current] = true
        local row, err = bridge.db.single(SELECT_RECIPE_SQL, { current, def.id })
        if err then return nil, 'db_error' end
        if not row then break end
        chain[#chain + 1] = { characterId = current, learnedAt = bridge.Integer(row.learned_at, 0), source = row.source }
        local teacher = row.taught_by ~= nil and bridge.Integer(row.taught_by, 0) or 0
        current = teacher ~= 0 and teacher or nil
    end
    if #chain == 0 then return nil, 'not_known' end
    local ids = {}
    for i, link in ipairs(chain) do ids[i] = link.characterId end
    local names = bridge.NamesOf(ids)
    for _, link in ipairs(chain) do link.name = names[link.characterId] or ('Personnage n° ' .. tostring(link.characterId)) end
    return { recipe = def.id, label = def.label, chain = chain }
end

--- Savoir donné par le Conseil ou un fondateur. Bloque le thread courant.
---@param characterId integer
---@param recipe any
---@param source 'founder'|'admin'
---@param actor { characterId?: integer, accountId?: integer }
---@return boolean ok
---@return string|nil code
function lessons.grant(characterId, recipe, source, actor)
    local def = registries.recipe(recipe)
    if not def then return false, 'unknown_recipe' end
    if not def.transmission then return false, 'not_transmitted' end
    if mathType(characterId) ~= 'integer' then return false, 'invalid_target' end
    return lessons.learn(characterId, def, source, nil, actor)
end
