--[[
    vava_skills/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registres du core, RPC,
           évènements ciblés, modes de rouille, bornes.
    Dépendances : aucune
]]

VavaSkills = {}

-- Registres du core définis par ce module : compétences (remplies par la config, extensibles) et recettes
-- (déclarées par vava_crafting et tout module qui enseigne un savoir).
VavaSkills.REGISTRY = {
    SKILLS = 'vava_skills:skills',
    RECIPES = 'vava_skills:recipes',
}

-- Modes de rouille (Ultima Online) : up gagne, keep est verrouillée (ni gain ni perte), down peut perdre et ne gagne pas.
VavaSkills.MODES = { up = true, keep = true, down = true }
VavaSkills.MODE_LIST = { 'up', 'keep', 'down' }

-- Bornes de validation (protocole).
VavaSkills.MAX_LEVEL = 100
VavaSkills.MAX_ID = 0xFFFFFFFF            -- identifiants de personnage (INT UNSIGNED)
VavaSkills.MAX_PROPOSAL_ID = 0x7FFFFFFF
VavaSkills.SKILL_PATTERN = '^[%l_]+$'     -- identifiant de compétence : lettres minuscules et soulignés
VavaSkills.RECIPE_PATTERN = '^[%l%d_]+$'  -- identifiant de recette

-- Intentions du client (RPC à schéma strict, débit limité).
VavaSkills.RPC = {
    SHEET = 'vava_skills:sheet',           -- fiche complète (ouverture du livre)
    MODE = 'vava_skills:setMode',          -- compétence, mode
    NEARBY = 'vava_skills:nearby',         -- joueurs à portée pour proposer un mentorat (noms de personnage)
    PROPOSE = 'vava_skills:propose',       -- numéro de joueur, compétence : proposer un mentorat
    ANSWER = 'vava_skills:answer',         -- numéro de proposition, accepté ?
    BREAK = 'vava_skills:break',           -- compétence, numéro de mentorat : rompre
    LINEAGE = 'vava_skills:lineage',       -- recette : lignée du savoir
    SHORTAGES = 'vava_skills:shortages',   -- métiers en pénurie (panneau d'affichage)
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaSkills.EVENTS = {
    SKILL = 'vava_skills:skill',           -- { skill = vue d'une compétence, budget }
    PROPOSAL = 'vava_skills:proposal',     -- { id, masterName, skill, skillLabel, expiresAt }
    MENTORSHIP = 'vava_skills:mentorship', -- { action = started | ended, skill, skillLabel, role, other, reason? }
    RECIPE = 'vava_skills:recipe',         -- { recipe, label, source }
    LESSON = 'vava_skills:lesson',         -- { recipe, label, count, required, role }
    NOTIFY = 'vava_skills:notify',         -- message, nature (info | warning | danger)
}
