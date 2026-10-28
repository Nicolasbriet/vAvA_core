--[[
    vava_chat/server/commands.lua
    Rôle : déclaration des commandes et de la touche du chat au registre `core:commands` du core (lu par le Codex et par
           les suggestions). Les noms viennent de la config : rien n'est écrit deux fois.
    Dépendances : config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaChat.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Chat'

local commands = {}
VavaChat.commands = commands

local function entries()
    local C = cfg.commands
    local message = { name = 'message', type = 'text', rest = true }
    return {
        [C.ooc] = { kind = 'command', scope = 'player', label = 'Parler hors-RP', description = 'Message hors-RP aux joueurs proches.', args = { message } },
        [C.mp] = { kind = 'command', scope = 'player', label = 'Message privé', description = 'Écrire en privé à un joueur en jeu.',
            args = { { name = 'joueur', type = 'player' }, message } },
        [C.reply] = { kind = 'command', scope = 'player', label = 'Répondre au dernier message privé', args = { message } },
        [C.me] = { kind = 'command', scope = 'player', label = 'Action de votre personnage',
            description = 'Décrit ce que fait votre personnage, vu des joueurs proches.',
            args = { { name = 'action', type = 'text', rest = true, hint = 'ex. : tire son épée' } } },
        [C['do']] = { kind = 'command', scope = 'player', label = 'Décrire la scène',
            description = 'Décrit un élément de la scène, vu des joueurs proches.',
            args = { { name = 'description', type = 'text', rest = true, hint = 'ex. : la porte est verrouillée' } } },
        [C.staff] = { kind = 'command', scope = 'admin', label = 'Canal du Conseil', description = 'Message aux seuls membres du Conseil.', args = { message } },
        [C.chat] = { kind = 'command', scope = 'player', label = 'Réglages du chat',
            actions = { { id = C.reset, label = 'Remettre le chat à sa place', description = 'Replace et redimensionne la fenêtre du chat comme au départ.' } } },
        [cfg.key.command] = { kind = 'key', scope = 'player', label = cfg.key.label, key = cfg.key.key, hold = true },
    }
end

--- Déclare les commandes et la touche du module. Appelé pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaChat.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaChat.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
