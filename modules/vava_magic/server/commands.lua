--[[
    vava_magic/server/commands.lua
    Rôle : déclaration des touches de la magie et de ses commandes (grimoire, sort, lancer, murmure, lueur, sigils, et la
           commande du Conseil) au registre `core:commands` du core (Codex, suggestions du chat). Les sorts des formulaires
           viennent du registre des sorts.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaMagic.config
local SPELLS = VavaMagic.SPELLS_REGISTRY
local REGISTRY = 'core:commands'
local CHAPTER = 'Magie'

local commands = {}
VavaMagic.commands = commands

local function entries()
    local C = cfg.commands
    local L, S, A = C.lightActions, C.sigilActions, C.adminActions
    local spell = { name = 'sort', type = 'registry', registry = SPELLS }
    local target = { name = 'joueur', type = 'player', optional = true, hint = 'sinon vous-même' }
    local list = {
        [C.grimoire] = { kind = 'command', scope = 'player', ui = true, label = 'Ouvrir votre grimoire' },
        [C.sort] = { kind = 'command', scope = 'player', label = 'Sort prêt dans vos mains',
            actions = {
                { label = 'Choisir un sort', args = { spell } },
                { id = C.none, label = 'Les mains vides' },
            } },
        [C.lancer] = { kind = 'command', scope = 'player', label = 'Lancer le sort choisi', description = 'Sans visée ; un autre sort connu peut être nommé.',
            args = { { name = 'sort', type = 'registry', registry = SPELLS, optional = true } } },
        [C.murmure] = { kind = 'command', scope = 'player', ui = true, label = 'Écrire un murmure',
            description = 'Sans argument, ouvre les murmures ; avec des numéros de contacts et un message, l\'envoie.',
            args = {
                { name = 'contacts', type = 'text', optional = true, hint = 'numéros séparés par des virgules' },
                { name = 'message', type = 'text', rest = true, optional = true },
            } },
        [C.lueur] = { kind = 'command', scope = 'player', label = 'Lueur',
            actions = {
                { label = 'Allumer ou éteindre la Lueur' },
                { id = L.anchor, label = 'Ancrer la Lueur sur place' },
                { id = L.color, label = 'Changer la couleur', args = { { name = 'couleur', type = 'text' } } },
                { id = L.off, label = 'Éteindre la Lueur' },
                { id = L.dispel, label = 'Dissiper les Lueurs proches' },
            } },
        [C.sigils] = { kind = 'command', scope = 'player', label = 'Lister vos sigils' },
        [C.sigil] = { kind = 'command', scope = 'player', label = 'Gérer vos sigils',
            actions = {
                { id = S.offer, label = 'Offrir votre sigil', description = 'Au personnage le plus proche.' },
                { id = S.rename, label = 'Renommer un sigil', args = { { name = 'n°', type = 'integer', min = 1, max = 99 }, { name = 'nom', type = 'text', rest = true } } },
                { id = S.forget, label = 'Oublier un sigil', args = { { name = 'n°', type = 'integer', min = 1, max = 99 } } },
                { id = S.scramble, label = 'Brouiller votre sigil', description = 'Les sigils déjà offerts cessent de vous atteindre.' },
            } },
        [C.admin] = { kind = 'command', scope = 'admin', permission = cfg.admin.permission, ace = cfg.admin.ace,
            label = 'Magie d\'un joueur', description = 'Faire mage, apprendre ou retirer des sorts, niveaux, mana, recharges, fiche, objets, nettoyage.',
            actions = {
                { id = A.mage, label = 'Faire ou défaire un mage', args = { target, { name = 'mage', type = 'choice', choices = { C.yes, C.no or 'non' }, labels = { [C.yes] = 'Oui', [C.no or 'non'] = 'Non' } } } },
                { id = A.learn, label = 'Apprendre un sort', args = { target, spell } },
                { id = A.forget, label = 'Retirer un sort', args = { target, spell } },
                { id = A.level, label = 'Fixer le niveau d\'un sort', args = { target, spell, { name = 'niveau', type = 'integer', min = 1, max = 5 } } },
                { id = A.xp, label = 'Fixer l\'XP d\'un sort', args = { target, spell, { name = 'xp', type = 'integer', min = 0, max = 100000 } } },
                { id = A.all, label = 'Apprendre tous les sorts', args = { target } },
                { id = A.master, label = 'Maîtriser tous les sorts', args = { target } },
                { id = A.clear, label = 'Retirer tous les sorts', args = { target } },
                { id = A.mana, label = 'Remplir la mana', args = { target } },
                { id = A.cooldowns, label = 'Effacer les recharges', args = { target } },
                { id = A.sheet, label = 'Lire la fiche de magie', args = { target } },
                { id = A.give, label = 'Donner un objet de magie', args = { target, { name = 'objet', type = 'choice', choices = { 'grimoire', 'registre' } } } },
                { id = A.cleanup, label = 'Nettoyer le monde', description = 'Retire les effets de magie oubliés dans le monde.' },
            } },
    }
    for _, key in pairs(cfg.keys) do
        list[key.command] = { kind = 'key', scope = 'player', key = key.key, keyDevice = key.device, keyDisplay = key.display, hold = key.hold, label = key.label }
    end
    return list
end

--- Déclare les touches et les commandes du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaMagic.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaMagic.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
