--[[
    vava_anim_test/server/main.lua
    Rôle : garde de l'outil de test des animations, et déclaration de ses commandes au Codex :
      - `setup` refuse sans `set vava_env dev` : aucun RPC, aucune entrée au Codex, et le client n'ouvre rien ;
      - RPC vava_anim_test:access : le client le demande avant chaque commande (réponse gardée `accessCacheMs`) ;
        accordé au seul droit vava_admin `staff` ou à l'ACE `vava.dev` (config `access`) ;
      - registre `core:commands` : commandes du chapitre « Tests », portée Conseil (`scope = 'admin'`, même droit) :
        hors du Codex des joueurs.
    Dépendances : vAvA_core ≥ 0.7.0, config.lua, shared/guard.lua ; facultatif : vava_admin (droit)
]]

local pcall, ipairs, tostring, pairs = pcall, ipairs, tostring, pairs
local format = string.format
local GetConvar, GetResourceState, IsPlayerAceAllowed = GetConvar, GetResourceState, IsPlayerAceAllowed

local RESOURCE = GetCurrentResourceName()
local cfg = VavaAnimTest.config
local guard = VavaAnimTest.guard
local C = cfg.commands
local ADMIN = 'vava_admin'
local REGISTRY = 'core:commands'
local CHAPTER = 'Tests'
local RPC_ACCESS = RESOURCE .. ':access'

local called, core = pcall(function() return exports.vAvA_core:getApi(1) end)
if not called or not core then
    print(('^3[%s] vAvA_core absent : outil inactif^7'):format(RESOURCE))
    return
end

--- Mode développement relu à chaque appel, puis droit vava_admin (appel isolé) ou ACE : rien d'autre n'ouvre l'outil.
---@param source integer
---@return boolean
local function allowed(source)
    local adminStarted = GetResourceState(ADMIN) == 'started'
    local adminCalled, adminCan = false, nil
    if adminStarted then
        adminCalled, adminCan = pcall(function() return exports[ADMIN]:can(source, cfg.access.permission) end)
    end
    return guard.allowed({
        devMode = guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)),
        adminStarted = adminStarted,
        adminCalled = adminCalled,
        adminCan = adminCan,
        ace = IsPlayerAceAllowed(source, cfg.access.ace) == true,
    })
end

local function entries()
    local flags = {}
    for _, entry in ipairs(cfg.flags) do flags[#flags + 1] = tostring(entry[1]) end
    local list = {
        [C.play] = { kind = 'command', label = 'Jouer une animation',
            description = 'Charge un dictionnaire (.ycd de stream/) et joue un clip ; sans clip, les noms courants sont essayés ; sans rien, rejoue la dernière.',
            args = {
                { name = 'dictionnaire', type = 'text', optional = true, hint = 'nom du fichier .ycd sans extension ; vide : rejouer la dernière' },
                { name = 'clip', type = 'text', optional = true, hint = 'vide : sondage des noms courants' },
                { name = 'drapeau', type = 'choice', choices = flags, optional = true, hint = '1 boucle, 49 haut du corps en boucle…' },
                { name = 'durée', type = 'integer', min = 100, max = 600000, optional = true, hint = 'millisecondes ; vide : durée du clip' },
            } },
        [C.stop] = { kind = 'command', label = 'Arrêter l\'animation' },
        [C.prop] = { kind = 'command', label = 'Accessoire en main (test de pose)',
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
        [C.flags] = { kind = 'command', label = 'Rappel des drapeaux d\'animation' },
    }
    for _, shortcut in ipairs(cfg.shortcuts) do
        list[shortcut.command] = { kind = 'command', label = shortcut.label,
            description = format('Joue %s%s (drapeau %d).', shortcut.dict, shortcut.clip and (' / ' .. shortcut.clip) or '', shortcut.flag or cfg.defaultFlag) }
    end
    -- outil de développement : vu au Codex du seul Conseil qui y a droit, jamais des joueurs
    for _, def in pairs(list) do
        def.scope, def.permission, def.ace = 'admin', cfg.access.permission, cfg.access.ace
    end
    return list
end

local function setup()
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return false, guard.REFUSAL end
    local ok, err = core.rpc.register(RPC_ACCESS, { args = {}, rateLimit = cfg.accessRateLimit }, function(source)
        if not allowed(source) then return false, 'not_allowed' end
        return true
    end)
    if not ok then return false, err end
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = RESOURCE, CHAPTER
        ok, err = core.registry.add(REGISTRY, name, def)
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
