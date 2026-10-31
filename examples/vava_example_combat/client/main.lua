--[[
    vava_example_combat/client/main.lua
    Rôle : commandes d'essai qui touchent au ped local, pour vérifier ce que le serveur annule ou corrige :
      - /arme pistolet | couteau | non : donne ou retire une arme vanilla (config `weapons`, provisoire) ;
      - /explosion : explosion vanilla à quelques mètres devant soi (config `explosion`, provisoire) ;
      - /tricher : vie GTA du ped local remise au maximum (simule un client qui refuse la vie du serveur ; seule
        exception voulue à « le client ne touche pas à la vie ») ;
      - réponses du serveur (vava_example_combat:message) affichées dans le chat.
      Chaque commande demande d'abord l'accord du serveur (RPC vava_example_combat:access : mode développement et
      droit, revérifiés à chaque appel). Aucune boucle, aucun envoi au serveur hors de cet accord.
    Dépendances : vAvA_core (API v1), config_client.lua
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExampleCombat.config

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local tostring, pairs, type = tostring, pairs, type
local format = string.format
local CreateThread, TriggerEvent, RegisterCommand, RegisterNetEvent = CreateThread, TriggerEvent, RegisterCommand,
    RegisterNetEvent
local PlayerPedId, GetHashKey, GiveWeaponToPed, RemoveWeaponFromPed = PlayerPedId, GetHashKey, GiveWeaponToPed, RemoveWeaponFromPed
local GetOffsetFromEntityInWorldCoords, AddExplosion = GetOffsetFromEntityInWorldCoords, AddExplosion
local SetEntityHealth, GetEntityMaxHealth = SetEntityHealth, GetEntityMaxHealth

local RPC_ACCESS = RESOURCE .. ':access'
local C = cfg.commands

---@param message string
local function say(message, ...)
    local text = format(message, ...)
    core.log.info(text)
    TriggerEvent('chat:addMessage', { args = { cfg.chatAuthor, text } })
end

-- réponses du serveur (à ce seul joueur) : texte brut affiché dans le chat
RegisterNetEvent(RESOURCE .. ':message', function(text)
    if type(text) == 'string' then say('%s', text) end
end)

--- Le serveur décide : mode développement et droit. Bloque le thread courant.
---@return boolean
local function granted()
    local ok, success, code = core.rpc.call(RPC_ACCESS)
    if ok and success then return true end
    say('refusé (%s).', tostring(ok and code or success))
    return false
end

--- Commande exécutée dans son propre thread, après l'accord du serveur.
---@param name string
---@param handler fun(args: string[])
local function command(name, handler)
    RegisterCommand(name, function(_, args)
        CreateThread(function()
            if granted() then handler(args) end
        end)
    end, false)
end

command(C.weapon, function(args)
    local ped = PlayerPedId()
    local choice = args[1] or ''
    if choice == 'non' then
        for _, model in pairs(cfg.weapons) do RemoveWeaponFromPed(ped, GetHashKey(model)) end
        say('armes d\'essai retirées.')
        return
    end
    local model = cfg.weapons[choice]
    if not model then
        say('usage : /%s pistolet | couteau | non', C.weapon)
        return
    end
    GiveWeaponToPed(ped, GetHashKey(model), cfg.ammo, false, true)
    say('%s en main (arme vanilla d\'essai).', choice)
end)

command(C.explosion, function()
    local coords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, cfg.explosion.distance, 0.0)
    AddExplosion(coords.x, coords.y, coords.z, cfg.explosion.type, 1.0, true, false, 1.0)
    say('explosion d\'essai à %.0f m devant vous.', cfg.explosion.distance)
end)

command(C.cheat, function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    say('vie GTA remise au maximum sur ce seul client : le serveur doit la corriger.')
end)
