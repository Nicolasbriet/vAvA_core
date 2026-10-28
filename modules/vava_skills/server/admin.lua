--[[
    vava_skills/server/admin.lua
    Rôle : commandes du Conseil. `vava_fondateur` (console, ou droit `staff`) nomme un fondateur : niveau d'une
           compétence et recettes transmises initiales, hors des règles de progression. `/metiers` (droit `metiers`)
           corrige un niveau, donne une recette, montre la fiche d'un joueur. Cibles : joueurs connectés avec un
           personnage en jeu (numéro de joueur). Chaque action est inscrite au journal du module et au Registre du
           Conseil.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/registries.lua, server/sheets.lua,
                  server/progression.lua, server/lessons.lua
]]

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local tointeger = math.tointeger
local format, concat = string.format, table.concat
local RegisterCommand, CreateThread = RegisterCommand, CreateThread

local bridge = VavaSkills.bridge
local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local experience = VavaSkills.experience
local lessons = VavaSkills.lessons
local rules = VavaSkills.progression
local cfg = VavaSkills.config.admin
local CONSOLE = bridge.CONSOLE

local admin = {}
VavaSkills.admin = admin

---@param source integer
---@return { source: integer, characterId: integer|nil, accountId: integer|nil }
local function actorOf(source)
    return { source = source, characterId = bridge.GetCharacterId(source), accountId = bridge.GetAccountId(source) }
end

--- Fiche d'un joueur connecté désigné par son numéro, ou nil avec un message d'erreur.
---@param value any
---@return vAvA.SkillSheet|nil
---@return string|nil err
local function targetOf(value)
    local src = tointeger(tonumber(value))
    if not src then return nil, 'numéro de joueur attendu' end
    local sheet = sheets.get(src)
    if not sheet then return nil, format('le joueur %d n\'a pas de personnage en jeu', src) end
    return sheet
end

---@param source integer
---@param sheet vAvA.SkillSheet
local function showSheet(source, sheet)
    bridge.Chat(source, format('%s (personnage n° %d) — budget %d / %d', sheet.name, sheet.characterId,
        rules.budgetUsed(sheet.skills), VavaSkills.config.levels.budget))
    for _, def in ipairs(registries.skills()) do
        local entry = sheet.skills[def.id]
        if entry and (entry.level > 0 or entry.mode ~= 'keep') then
            bridge.Chat(source, format('  %s : %d (%s, %s, Renommée %d)', def.label, entry.level, rules.rankOf(entry.level).label, entry.mode, entry.renown))
        end
    end
    local recipes = {}
    for recipe in pairs(sheet.recipes) do recipes[#recipes + 1] = recipe end
    if #recipes > 0 then bridge.Chat(source, '  Savoirs transmis : ' .. concat(recipes, ', ')) end
end

--- vava_fondateur <joueur> <compétence> <niveau> [recette ...]
---@param source integer
---@param args string[]
local function founderCommand(source, args)
    if not bridge.IsAllowed(source, cfg.founderPermission) then return end
    local sheet, err = targetOf(args[1])
    local skill = registries.skill(args[2])
    local level = tointeger(tonumber(args[3]))
    if not sheet or not skill or not level then
        bridge.Chat(source, err or format('usage : %s <joueur> <compétence> <niveau> [recette ...]', cfg.commands.founder))
        return
    end
    CreateThread(function()
        local actor = actorOf(source)
        local ok, code = experience.setLevel(sheet.characterId, skill.id, level, 'founder', actor)
        if not ok then
            bridge.Chat(source, 'niveau refusé : ' .. tostring(code))
            return
        end
        local granted = {}
        for i = 4, #args do
            local accepted, why = lessons.grant(sheet.characterId, args[i], 'founder', actor)
            if accepted then granted[#granted + 1] = args[i] else bridge.Chat(source, format('recette %s refusée : %s', args[i], tostring(why))) end
        end
        bridge.AdminLog(source, 'Fondateur nommé', { joueur = sheet.name, competence = skill.id, niveau = level, recettes = #granted })
        bridge.Chat(source, format('%s : %s au niveau %d, %d recette(s) transmise(s).', sheet.name, skill.label, level, #granted))
    end)
end

--- /metiers niveau <joueur> <compétence> <niveau> · /metiers recette <joueur> <recette> · /metiers voir <joueur>
---@param source integer
---@param args string[]
local function metiersCommand(source, args)
    if not bridge.IsAllowed(source, cfg.permission) then return end
    local action = args[1]
    local sheet, err = targetOf(args[2])
    if not sheet then
        bridge.Chat(source, err or format('usage : /%s niveau|recette|voir <joueur> …', cfg.commands.metiers))
        return
    end
    CreateThread(function()
        local actor = actorOf(source)
        if action == 'voir' then
            showSheet(source, sheet)
        elseif action == 'niveau' then
            local skill = registries.skill(args[3])
            local level = tointeger(tonumber(args[4]))
            if not skill or not level then
                bridge.Chat(source, format('usage : /%s niveau <joueur> <compétence> <niveau>', cfg.commands.metiers))
                return
            end
            local ok, code = experience.setLevel(sheet.characterId, skill.id, level, 'admin_set', actor)
            if not ok then
                bridge.Chat(source, 'refusé : ' .. tostring(code))
                return
            end
            bridge.AdminLog(source, 'Compétence corrigée', { joueur = sheet.name, competence = skill.id, niveau = level })
            bridge.Chat(source, format('%s : %s au niveau %d.', sheet.name, skill.label, level))
        elseif action == 'recette' then
            local ok, code = lessons.grant(sheet.characterId, args[3], 'admin', actor)
            if not ok then
                bridge.Chat(source, 'refusé : ' .. tostring(code))
                return
            end
            bridge.AdminLog(source, 'Recette donnée', { joueur = sheet.name, recette = tostring(args[3]) })
            bridge.Chat(source, format('%s connaît désormais %s.', sheet.name, tostring(args[3])))
        else
            bridge.Chat(source, format('usage : /%s niveau|recette|voir <joueur> …', cfg.commands.metiers))
        end
    end)
end

--- Enregistre les commandes. Appelé pendant le setup du module.
function admin.start()
    -- `true` : commande restreinte pour le jeu (ACE) ; nos propres contrôles de droit s'appliquent dans tous les cas
    RegisterCommand(cfg.commands.founder, founderCommand, true)
    RegisterCommand(cfg.commands.metiers, metiersCommand, false)
end

admin.CONSOLE = CONSOLE
