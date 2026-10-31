--[[
    vava_combat/client/natives.lua
    Rôle : coupe le combat natif de GTA SANS boucle par image : drapeau de ped « corps à corps désactivé », changement
           d'arme bloqué, armes GTA retirées. Ces bascules gardent leur effet jusqu'au changement de ped : un contrôle à
           `natives.pollMs` (1 s) les réapplique sur un nouveau ped ou si le drapeau a été perdu, et retire toute arme
           GTA en main (menu de triche, /arme de l'exemple). Au repos : trois natives par seconde. La coupure par image
           des touches (attaque, visée, roue) appartiendra au mode combat de T-112, éveillé et borné dans le temps. Le
           filet reste l'annulation serveur des dégâts natifs (vava_health). À l'arrêt du module, avec
           `restoreOnStop`, drapeau et changement d'arme sont rendus à GTA.
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, DoesEntityExist, GetHashKey = PlayerPedId, DoesEntityExist, GetHashKey
local GetPedConfigFlag, SetPedConfigFlag, SetPedCanSwitchWeapon = GetPedConfigFlag, SetPedConfigFlag, SetPedCanSwitchWeapon
local GetSelectedPedWeapon, RemoveAllPedWeapons = GetSelectedPedWeapon, RemoveAllPedWeapons
local GetCurrentResourceName = GetCurrentResourceName

local cfg = VavaCombat.config.natives
local RESOURCE = GetCurrentResourceName()
local UNARMED = GetHashKey('WEAPON_UNARMED')
-- une ligne de console client par minute au plus pour les armes retirées
local WARN_MS = 60000

local natives = {}
VavaCombat.natives = natives

local lastPed = 0
local warnedAt = nil
local running = false

---@param ped integer
local function apply(ped)
    if cfg.disableMelee then SetPedConfigFlag(ped, cfg.meleeFlag, true) end
    if cfg.blockSwitch then SetPedCanSwitchWeapon(ped, false) end
end

--- Un contrôle : bascules réappliquées sur un nouveau ped (ou drapeau perdu), arme GTA retirée.
local function check()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end
    if ped ~= lastPed or (cfg.disableMelee and not GetPedConfigFlag(ped, cfg.meleeFlag, true)) then
        apply(ped)
        lastPed = ped
    end
    if cfg.stripWeapons and GetSelectedPedWeapon(ped) ~= UNARMED then
        RemoveAllPedWeapons(ped, true)
        local now = GetGameTimer()
        if not warnedAt or now - warnedAt >= WARN_MS then
            warnedAt = now
            VavaCombat.log.info('arme de GTA retirée : on ne se bat qu\'avec ce que le royaume a façonné')
        end
    end
end

--- Lance le contrôle lent (une seule fois). Boucle permanente justifiée : 1 Hz, trois natives au repos, jamais Wait(0).
function natives.start()
    if running then return end
    running = true
    CreateThread(function()
        while running do
            check()
            Wait(cfg.pollMs)
        end
    end)
end

-- arrêt du module : le corps à corps et le changement d'arme sont rendus à GTA (sans dégâts entre joueurs : vava_health)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    running = false
    if not cfg.restoreOnStop then return end
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end
    if cfg.disableMelee then SetPedConfigFlag(ped, cfg.meleeFlag, false) end
    if cfg.blockSwitch then SetPedCanSwitchWeapon(ped, true) end
end)
