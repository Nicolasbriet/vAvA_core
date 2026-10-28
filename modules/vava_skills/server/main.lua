--[[
    vava_skills/server/main.lua
    Rôle : déclaration du module auprès du core : registres, journal, pénurie, intentions du client (RPC à schéma
           strict et débit limité : fiche, mode, mentorat, lignée, pénurie), arrivée et départ des personnages (fiche
           chargée avant l'apparition, écrite au départ), personnage supprimé, écritures régulières, commandes du
           Conseil. Un module (re)démarré en cours de partie reprend les personnages déjà en jeu.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local AddEventHandler, GetPlayers = AddEventHandler, GetPlayers

local core = VavaSkills.core
if not core then return end

local bridge = VavaSkills.bridge
local journal = VavaSkills.journal
local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local shortages = VavaSkills.shortages
local experience = VavaSkills.experience
local mentoring = VavaSkills.mentoring
local lessons = VavaSkills.lessons
local admin = VavaSkills.admin
local cfg = VavaSkills.config
local limits = cfg.rateLimits
local RPC = VavaSkills.RPC

local SKILL = { type = 'string', min = 1, max = 32, pattern = VavaSkills.SKILL_PATTERN }
local RECIPE = { type = 'string', min = 1, max = 64, pattern = VavaSkills.RECIPE_PATTERN }
local MODE = { type = 'string', enum = VavaSkills.MODE_LIST }
local PLAYER = { type = 'integer', min = 1, max = 0xFFFF }
local PROPOSAL = { type = 'integer', min = 1, max = VavaSkills.MAX_PROPOSAL_ID }
local MENTORSHIP = { type = 'integer', min = 1, max = VavaSkills.MAX_ID }
local BOOL = { type = 'boolean' }

--- Personnage arrivé : fiche chargée (bloque le thread du core le temps des lectures).
---@param src integer
local function arrive(src)
    local character = bridge.GetCharacter(src) or core.characters.getActive(src)
    if not character then return end
    if sheets.get(src) then return end
    if not sheets.load(src, character) then
        VavaSkills.log.error('fiche de compétences du personnage %d non chargée', character.id)
    end
end

--- Départ du personnage : propositions oubliées, fiche écrite puis libérée.
---@param src integer
local function leave(src)
    mentoring.forget(src)
    experience.forget(src)
    sheets.unload(src)
end

local function setup()
    local declared, declareErr = VavaSkills.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = registries.define()
    if not ok then return false, 'registres : ' .. tostring(err) end
    journal.purge()
    shortages.start()

    for _, def in ipairs({
        { RPC.SHEET, {}, limits.sheet, function(src)
            local sheet = sheets.get(src)
            if not sheet then return false, 'no_character' end
            return true, sheets.view(sheet)
        end },
        { RPC.MODE, { SKILL, MODE }, limits.mode, experience.setMode },
        { RPC.NEARBY, {}, limits.mentor, function(src)
            if not sheets.get(src) then return false, 'no_character' end
            return true, mentoring.nearby(src)
        end },
        { RPC.PROPOSE, { PLAYER, SKILL }, limits.mentor, mentoring.propose },
        { RPC.ANSWER, { PROPOSAL, BOOL }, limits.mentor, mentoring.answer },
        { RPC.BREAK, { MENTORSHIP }, limits.mentor, mentoring.breakUp },
        { RPC.LINEAGE, { RECIPE }, limits.lineage, function(src, recipe)
            local sheet = sheets.get(src)
            if not sheet then return false, 'no_character' end
            local result, code = lessons.lineage(sheet.characterId, recipe)
            if not result then return false, code end
            return true, result
        end },
        { RPC.SHORTAGES, {}, limits.shortages, function()
            return true, shortages.list()
        end },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end

    for _, def in ipairs({
        { 'core:character:loaded', function(payload) arrive(payload.source) end },
        { 'core:character:unloading', function(payload) leave(payload.source) end },
        { 'core:player:dropped', function(payload) leave(payload.source) end },
        { 'core:character:deleted', function(payload) mentoring.forgetCharacter(payload.characterId) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end

    sheets.start()
    admin.start()
    VavaSkills.ready = true
    -- module (re)démarré en cours de partie : fiches des personnages déjà en jeu
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and bridge.GetCharacterId(src) then arrive(src) end
    end
    return true
end

-- arrêt du module : fiches écrites (une transaction), propositions oubliées
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaSkills.resource or not VavaSkills.ready then return end
    for src in pairs(sheets.all()) do mentoring.forget(src) end
    sheets.flush()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaSkills.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
