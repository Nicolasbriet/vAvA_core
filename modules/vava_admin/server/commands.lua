--[[
    vava_admin/server/commands.lua
    Rôle : déclaration des commandes et touches du Registre du Conseil au registre `core:commands` du core (lu par le
           Codex et par les suggestions du chat) : ouverture du Registre, vol libre, signalement des joueurs, commandes
           de la console (nommer au Conseil, bannir, expulser).
    Dépendances : config.lua, server/core.lua, server/console.lua (noms des commandes de la console)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format

local cfg = VavaAdmin.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Conseil'
-- mot qui révoque un rang dans vava_conseil (server/console.lua)
local REMOVE = 'aucun'

local commands = {}
VavaAdmin.commands = commands

local function entries()
    local ranks, labels = {}, {}
    for _, rank in ipairs(cfg.ranks) do
        ranks[#ranks + 1] = rank.name
        labels[rank.name] = rank.label
    end
    ranks[#ranks + 1] = REMOVE
    labels[REMOVE] = 'Révoquer'
    local reason = { name = 'motif', type = 'text', rest = true }
    return {
        [cfg.openCommand] = { kind = 'command', scope = 'admin', key = cfg.keys.open, ui = true, label = 'Registre du Conseil',
            description = 'Ouvrir le Registre du Conseil : joueurs, signalements, journal, bans.' },
        -- même droit que le RPC `tool` du Registre (server/requests.lua)
        [cfg.noclipCommand] = { kind = 'key', scope = 'admin', permission = 'tools', key = cfg.keys.noclip, label = cfg.labels.noclip },
        [cfg.reportCommand] = { kind = 'command', scope = 'player', label = 'Signaler au Conseil',
            description = 'Transmettre un signalement au Conseil (un par minute).', args = { { name = 'message', type = 'text', rest = true } } },
        vava_conseil = { kind = 'command', scope = 'console', label = 'Nommer ou révoquer un membre du Conseil',
            description = 'Donne un rang du Conseil à un compte, ou le lui retire (« ' .. REMOVE .. ' »). Le premier membre ne se nomme qu\'ici.',
            args = { { name = 'compte', type = 'account' }, { name = 'rang', type = 'choice', choices = ranks, labels = labels } } },
        vava_ban = { kind = 'command', scope = 'console', label = 'Bannir un compte',
            description = 'Bannit un compte, connecté ou non, pour un nombre d\'heures (0 : définitif).',
            args = { { name = 'compte', type = 'account' }, { name = 'heures', type = 'integer', min = 0, max = 87600, hint = '0 = définitif' }, reason } },
        vava_unban = { kind = 'command', scope = 'console', label = 'Lever les bans d\'un compte', args = { { name = 'compte', type = 'account' } } },
        vava_kick = { kind = 'command', scope = 'console', label = 'Expulser un joueur', args = { { name = 'joueur', type = 'player' }, reason } },
    }
end

--- Déclare les commandes et touches du module. Appelé pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaAdmin.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaAdmin.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
