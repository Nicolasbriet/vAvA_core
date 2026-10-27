--[[
    vava_example/client/main.lua
    Rôle : démonstration côté client : commande /note (intention envoyée au serveur), handler de ping appelé
           par le serveur, et réaction aux hooks client du personnage (chargement, compteur synchronisé).
    Dépendances : vAvA_core (API v1)
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local log = core.log
local concat = table.concat
local GetGameTimer = GetGameTimer

local RPC_POST_NOTE = RESOURCE .. ':postNote'
local RPC_PING = RESOURCE .. ':ping'
local FIELD_NOTES_PUBLISHED = RESOURCE .. ':notesPublished'

-- reçus du core pour SON personnage uniquement
core.hooks.after('core:character:loaded', function(character)
    log.info('%s %s : %d note(s) publiée(s)', character.firstName, character.lastName,
        character.fields[FIELD_NOTES_PUBLISHED] or 0)
end)
core.hooks.after('core:character:fieldChanged', function(change)
    if change.field == FIELD_NOTES_PUBLISHED then
        log.info('notes publiées par ce personnage : %d', change.value or 0)
    end
end)

local registered, registerErr = core.rpc.register(RPC_PING, function()
    return GetGameTimer()
end)
if not registered then
    log.error('handler ping non enregistré : %s', tostring(registerErr))
end

-- /note <type> <message> : le client n'envoie qu'une intention ; le serveur valide et décide.
RegisterCommand('note', function(_, args)
    local noteType = args[1]
    local content = concat(args, ' ', 2)
    if not noteType or content == '' then
        log.warn('usage : /note <type> <message>')
        return
    end
    CreateThread(function()
        -- ok : succès du transport · success/result : réponse du handler serveur
        local ok, success, result = core.rpc.call(RPC_POST_NOTE, noteType, content)
        if not ok then
            log.warn('appel impossible : %s', tostring(success))
        elseif not success then
            log.warn('note refusée : %s', tostring(result))
        else
            log.info('note #%d publiée', result)
        end
    end)
end, false)
