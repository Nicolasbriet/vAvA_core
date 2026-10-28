--[[
    vava_anim_test/server/main.lua
    Rôle : déclare les commandes de test au registre `core:commands` du core, pour qu'elles apparaissent dans le
           Codex (chapitre « Tests ») et dans les suggestions du chat. Sans vAvA_core, la ressource marche quand même :
           les commandes sont côté client, seul le Codex les ignore.
    Dépendances : config.lua ; facultatif : vAvA_core ≥ 0.7.0
]]

local pcall, ipairs, tostring, pairs = pcall, ipairs, tostring, pairs
local format = string.format

local RESOURCE = GetCurrentResourceName()
local cfg = VavaAnimTest.config
local C = cfg.commands
local REGISTRY = 'core:commands'
local CHAPTER = 'Tests'

local called, core = pcall(function() return exports.vAvA_core:getApi(1) end)
if not called or not core then
    print(('^3[%s] vAvA_core absent : commandes hors du Codex^7'):format(RESOURCE))
    return
end

local function entries()
    local flags = {}
    for _, entry in ipairs(cfg.flags) do flags[#flags + 1] = tostring(entry[1]) end
    local list = {
        [C.play] = { kind = 'command', scope = 'player', label = 'Jouer une animation',
            description = 'Charge un dictionnaire (.ycd de stream/) et joue un clip ; sans clip, les noms courants sont essayés ; sans rien, rejoue la dernière.',
            args = {
                { name = 'dictionnaire', type = 'text', optional = true, hint = 'nom du fichier .ycd sans extension ; vide : rejouer la dernière' },
                { name = 'clip', type = 'text', optional = true, hint = 'vide : sondage des noms courants' },
                { name = 'drapeau', type = 'choice', choices = flags, optional = true, hint = '1 boucle, 49 haut du corps en boucle…' },
                { name = 'durée', type = 'integer', min = 100, max = 600000, optional = true, hint = 'millisecondes ; vide : durée du clip' },
            } },
        [C.stop] = { kind = 'command', scope = 'player', label = 'Arrêter l\'animation' },
        [C.prop] = { kind = 'command', scope = 'player', label = 'Accessoire en main (test de pose)',
            description = 'Accroche un modèle à la main droite pour juger la pose ; sans modèle, le retire.',
            args = {
                { name = 'modèle', type = 'text', optional = true, hint = 'ex. w_me_machete_lr ; vide : retirer' },
                { name = 'os', type = 'integer', min = 0, max = 65535, optional = true, hint = '57005 : main droite' },
                { name = 'x', type = 'number', min = -1, max = 1, step = 0.01, optional = true },
                { name = 'y', type = 'number', min = -1, max = 1, step = 0.01, optional = true },
                { name = 'z', type = 'number', min = -1, max = 1, step = 0.01, optional = true },
                { name = 'rx', type = 'number', min = -180, max = 180, step = 1, optional = true },
                { name = 'ry', type = 'number', min = -180, max = 180, step = 1, optional = true },
                { name = 'rz', type = 'number', min = -180, max = 180, step = 1, optional = true },
            } },
        [C.flags] = { kind = 'command', scope = 'player', label = 'Rappel des drapeaux d\'animation' },
    }
    for _, shortcut in ipairs(cfg.shortcuts) do
        list[shortcut.command] = { kind = 'command', scope = 'player', label = shortcut.label,
            description = format('Joue %s%s (drapeau %d).', shortcut.dict, shortcut.clip and (' / ' .. shortcut.clip) or '', shortcut.flag or cfg.defaultFlag) }
    end
    return list
end

local function setup()
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = RESOURCE, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = '0.7.0',
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
