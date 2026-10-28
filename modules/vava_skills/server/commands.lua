--[[
    vava_skills/server/commands.lua
    Rôle : déclaration de la touche du livre et des commandes du Conseil (/metiers, vava_fondateur) au registre
           `core:commands` du core (Codex, suggestions du chat). Les compétences et recettes des formulaires viennent
           des registres du module.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, client/main.lua (nom de la commande du livre)
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaSkills.config
local SKILLS, RECIPES = VavaSkills.REGISTRY.SKILLS, VavaSkills.REGISTRY.RECIPES
local REGISTRY = 'core:commands'
local CHAPTER = 'Compétences'
-- même nom que client/main.lua
local OPEN_COMMAND = 'vava_skills'

local commands = {}
VavaSkills.commands = commands

local function entries()
    local admin = cfg.admin
    local player = { name = 'joueur', type = 'player' }
    local skill = { name = 'compétence', type = 'registry', registry = SKILLS }
    local level = { name = 'niveau', type = 'integer', min = 0, max = cfg.levels.max }
    return {
        [OPEN_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.open, label = cfg.labels.open },
        [admin.commands.metiers] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Compétences d\'un joueur', description = 'Corriger un niveau, donner une recette ou lire la fiche d\'un joueur.',
            actions = {
                { id = 'niveau', label = 'Corriger un niveau', description = 'Fixe le niveau d\'une compétence (l\'XP en cours est remise à zéro).', args = { player, skill, level } },
                { id = 'recette', label = 'Donner une recette', args = { player, { name = 'recette', type = 'registry', registry = RECIPES } } },
                { id = 'voir', label = 'Lire la fiche', description = 'Compétences, rangs et budget du joueur, dans le chat.', args = { player } },
            } },
        [admin.commands.founder] = { kind = 'command', scope = 'console', label = 'Nommer un fondateur',
            description = 'Fixe le niveau d\'une compétence et donne des recettes d\'origine (lignée « fondateur »). Console, ou ACE.',
            args = { player, skill, level, { name = 'recettes', type = 'text', rest = true, optional = true, hint = 'identifiants de recettes séparés par des espaces' } } },
    }
end

--- Déclare la touche et les commandes du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaSkills.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaSkills.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
