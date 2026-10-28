--[[
    vava_skills/server/api.lua
    Rôle : exports serveur pour les modules métiers (récolte, artisanat, agriculture) et les autres : XP avec contexte,
           niveaux et rangs, recettes connues, leçons, fragments, mentorat, Renommée, lignées, pénurie. Cible : un
           joueur (son personnage actif). Aucune fonction ne lève d'erreur : `valeur` ou `false/nil, code`.
    Dépendances : server/core.lua, server/registries.lua, server/sheets.lua, server/shortages.lua,
                  server/progression.lua, server/mentoring.lua, server/lessons.lua
]]

local type, pairs = type, pairs
local mathType = math.type
local GetInvokingResource = GetInvokingResource

local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local shortages = VavaSkills.shortages
local experience = VavaSkills.experience
local mentoring = VavaSkills.mentoring
local lessons = VavaSkills.lessons
local rules = VavaSkills.progression

---@param source any
---@return vAvA.SkillSheet|nil
---@return string|nil code
local function sheetOf(source)
    if not VavaSkills.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' then return nil, 'invalid_target' end
    local sheet = sheets.get(source)
    if not sheet then return nil, 'no_character' end
    return sheet
end

--- XP avec contexte : `{ skill, source?, difficulty?, amount? }`. `true, { gained, level, rank, leveledUp, blocked? }`.
exports('addXp', function(source, ctx)
    local sheet, code = sheetOf(source)
    if not sheet then return false, code end
    return experience.addXp(source, ctx)
end)

--- Niveau et nom du rang d'une compétence (0, 'novice' si jamais pratiquée).
exports('getLevel', function(source, skill)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    if not registries.skill(skill) then return nil, 'unknown_skill' end
    local level = sheets.level(sheet, skill)
    return level, rules.rankOf(level).name
end)

--- Vrai si le joueur atteint le rang nommé dans la compétence.
exports('hasRank', function(source, skill, rankName)
    local sheet = sheetOf(source)
    if not sheet or not registries.skill(skill) then return false end
    return rules.hasRank(sheets.level(sheet, skill), rankName)
end)

--- Vue complète d'une compétence (niveau, XP, rang, mode, Renommée, pénurie, mentorat), ou nil.
exports('getSkill', function(source, skill)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    local view = sheets.skillView(sheet, skill)
    if not view then return nil, 'unknown_skill' end
    return view
end)

--- Toutes les compétences du joueur, dans l'ordre d'affichage, et son budget.
exports('getSkills', function(source)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    local list = {}
    for _, def in pairs(registries.skills()) do list[#list + 1] = sheets.skillView(sheet, def.id) end
    return list, sheets.budget(sheet)
end)

--- Vrai si le joueur connaît la recette (niveau pour une recette libre, apprentissage pour une recette transmise).
exports('knowsRecipe', function(source, recipe)
    local sheet = sheetOf(source)
    return sheet ~= nil and lessons.knows(sheet, recipe)
end)

--- Le professeur vient de réaliser `recipe` devant l'élève : une leçon de plus. `true, { count, required, learned }`.
exports('recordLesson', function(teacher, student, recipe)
    if not VavaSkills.ready then return false, 'not_ready' end
    if mathType(teacher) ~= 'integer' or mathType(student) ~= 'integer' then return false, 'invalid_target' end
    return lessons.recordLesson(teacher, student, recipe)
end)

--- Un fragment de savoir perdu réuni par le joueur. `true, { found, total, learned }`.
exports('addFragment', function(source, recipe, fragment)
    local sheet, code = sheetOf(source)
    if not sheet then return false, code end
    if type(fragment) ~= 'string' then return false, 'unknown_fragment' end
    return lessons.addFragment(source, recipe, fragment)
end)

--- Donne une recette transmise au nom du module appelant (journalisé comme `admin`).
exports('grantRecipe', function(source, recipe)
    local sheet, code = sheetOf(source)
    if not sheet then return false, code end
    return lessons.grant(sheet.characterId, recipe, 'admin', { characterId = nil, accountId = nil, module = GetInvokingResource() })
end)

--- Maître du joueur dans une compétence : { mentorshipId, characterId, name, since, online }, ou nil.
exports('getMentor', function(source, skill)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    local view = sheets.skillView(sheet, skill)
    if not view then return nil, 'unknown_skill' end
    return view.mentor
end)

--- Apprentis du joueur dans une compétence : liste { mentorshipId, characterId, name, since, online }.
exports('getApprentices', function(source, skill)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    local view = sheets.skillView(sheet, skill)
    if not view then return nil, 'unknown_skill' end
    return view.apprentices
end)

--- Vrai si le joueur pratique en ce moment sous le bonus de son maître (à portée, maître actif récemment).
exports('isMentoredNow', function(source, skill)
    local sheet = sheetOf(source)
    if not sheet or not registries.skill(skill) then return false end
    return mentoring.bonusFor(sheet, skill) ~= nil
end)

--- Renommée du joueur dans une compétence.
exports('getRenown', function(source, skill)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    if not registries.skill(skill) then return nil, 'unknown_skill' end
    local entry = sheet.skills[skill]
    return entry and entry.renown or 0
end)

--- Lignée d'un savoir du joueur : { recipe, label, chain = { { characterId, name, learnedAt, source } } }.
exports('getLineage', function(source, recipe)
    local sheet, code = sheetOf(source)
    if not sheet then return nil, code end
    return lessons.lineage(sheet.characterId, recipe)
end)

--- Métiers en pénurie : { { skill, label, count, multiplier } }.
exports('getShortages', function()
    if not VavaSkills.ready then return nil, 'not_ready' end
    return shortages.list()
end)

--- Multiplicateur d'XP d'une compétence en pénurie (1 sinon).
exports('shortageMultiplier', function(skill)
    if not VavaSkills.ready then return 1 end
    return shortages.multiplier(skill) or 1
end)
