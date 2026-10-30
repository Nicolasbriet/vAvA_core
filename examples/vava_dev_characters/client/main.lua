--[[
    vava_dev_characters/client/main.lua
    Rôle : commandes de test : /perso liste | creer <prénom> <nom> <h|f> | choisir <id> | quitter | supprimer <id>,
           /respawn, /objet <nom> [quantité], /besoins [faim] [soif], /vie [pourcentage] et /aterre. Chaque commande
           n'est qu'une intention : le serveur valide et décide. /perso appelle les RPC du core : il demande d'abord
           l'accès au serveur (vava_dev_characters:access, refusé sans mode développement ni droit).
    Dépendances : vAvA_core (API v1), config.lua
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaDevCharacters.config

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local tostring, tonumber = tostring, tonumber
local tointeger = math.tointeger
local format = string.format
local CreateThread, TriggerEvent = CreateThread, TriggerEvent

local RPC_ACCESS = RESOURCE .. ':access'
local RPC_RESPAWN = RESOURCE .. ':respawn'
local RPC_GIVE = RESOURCE .. ':give'
local RPC_NEEDS = RESOURCE .. ':needs'
local RPC_HEALTH = RESOURCE .. ':health'
local RPC_DOWN = RESOURCE .. ':down'
local USAGE = format('/%s liste | creer <prénom> <nom> <h|f> | choisir <id> | quitter | supprimer <id>', cfg.command)

---@param message string
local function notify(message, ...)
    local text = format(message, ...)
    core.log.info(text)
    -- affichage dans le chat s'il est présent (event local, sans effet sinon)
    TriggerEvent('chat:addMessage', { args = { cfg.chatAuthor, text } })
end

--- Affiche le résultat d'un appel : échec de transport, refus du serveur, ou succès.
---@return boolean success
local function report(action, ok, success, result)
    if not ok then
        notify('%s : appel impossible (%s)', action, cfg.refusals[success] or tostring(success))
        return false
    end
    if not success then
        notify('%s : refusé (%s)', action, cfg.refusals[result] or tostring(result))
        return false
    end
    return true
end

local subcommands = {}

function subcommands.liste()
    local ok, success, list = core.characters.list()
    if not report('liste', ok, success, list) then return end
    if #list == 0 then
        notify('aucun personnage : %s creer <prénom> <nom> <h|f>', cfg.command)
        return
    end
    for i = 1, #list do
        local c = list[i]
        notify('#%d %s %s (%s)', c.id, c.firstName, c.lastName, cfg.sexLabels[c.sex] or c.sex)
    end
end

function subcommands.creer(args)
    local sex = cfg.sexes[args[4] or '']
    if not args[2] or not args[3] or not sex then
        notify('usage : /%s creer <prénom> <nom> <h|f>', cfg.command)
        return
    end
    local ok, success, character = core.characters.create(args[2], args[3], sex)
    if report('création', ok, success, character) then
        notify('personnage #%d créé : %s %s — /%s choisir %d', character.id, character.firstName, character.lastName, cfg.command, character.id)
    end
end

function subcommands.choisir(args)
    local id = tointeger(tonumber(args[2]))
    if not id then
        notify('usage : /%s choisir <id>', cfg.command)
        return
    end
    local ok, success, code = core.characters.select(id)
    if report('sélection', ok, success, code) then notify('personnage #%d chargé', id) end
end

function subcommands.quitter()
    local ok, success, code = core.characters.unload()
    if report('déchargement', ok, success, code) then notify('retour à la sélection') end
end

function subcommands.supprimer(args)
    local id = tointeger(tonumber(args[2]))
    if not id then
        notify('usage : /%s supprimer <id>', cfg.command)
        return
    end
    local ok, success, code = core.characters.delete(id)
    if report('suppression', ok, success, code) then notify('personnage #%d supprimé', id) end
end

RegisterCommand(cfg.command, function(_, args)
    local handler = subcommands[args[1] or '']
    if not handler then
        notify(USAGE)
        return
    end
    CreateThread(function()
        -- les RPC de /perso sont ceux du core : l'accès aux outils est demandé au serveur d'abord
        local ok, success, code = core.rpc.call(RPC_ACCESS)
        if report(cfg.command, ok, success, code) then handler(args) end
    end)
end, false)

-- /objet <nom> [quantité] : objet donné au personnage actif (test de l'inventaire)
RegisterCommand(cfg.giveCommand, function(_, args)
    local item = args[1]
    local quantity = args[2] and tointeger(tonumber(args[2]))
    if not item or (args[2] and not quantity) then
        notify('usage : /%s <nom> [quantité]', cfg.giveCommand)
        return
    end
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC_GIVE, item, quantity)
        if report('objet', ok, success, code) then notify('%s × %d ajouté', item, quantity or 1) end
    end)
end, false)

-- /besoins [faim] [soif] : affiche, ou fixe, les besoins du personnage actif (test de vava_needs)
RegisterCommand(cfg.needsCommand, function(_, args)
    local hunger = args[1] and tonumber(args[1])
    local thirst = args[2] and tonumber(args[2])
    if (args[1] and not hunger) or (args[2] and not thirst) then
        notify('usage : /%s [faim] [soif] (0 à 100)', cfg.needsCommand)
        return
    end
    CreateThread(function()
        local ok, success, values = core.rpc.call(RPC_NEEDS, hunger, thirst)
        if report('besoins', ok, success, values) then notify('faim %.1f · soif %.1f', values.hunger, values.thirst) end
    end)
end, false)

-- /vie [pourcentage] : affiche, ou fixe, la vie du personnage actif ; /aterre : se met à terre (test de vava_health)
RegisterCommand(cfg.healthCommand, function(_, args)
    local percent = args[1] and tonumber(args[1])
    if args[1] and not percent then
        notify('usage : /%s [pourcentage]', cfg.healthCommand)
        return
    end
    CreateThread(function()
        local ok, success, state = core.rpc.call(RPC_HEALTH, percent)
        if report('vie', ok, success, state) then
            notify(state.downed and 'à terre' or 'vie %.0f %%', state.health)
        end
    end)
end, false)

RegisterCommand(cfg.downCommand, function()
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC_DOWN)
        report('à terre', ok, success, code)
    end)
end, false)

RegisterCommand(cfg.respawnCommand, function()
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC_RESPAWN)
        report('réapparition', ok, success, code)
    end)
end, false)
