--[[
    vAvA_core - Events Constants
    Centralisation de tous les événements du framework
]]

vCore = vCore or {}
vCore.Events = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS PLAYER
-- ═══════════════════════════════════════════════════════════════════════════

-- Connection
vCore.Events.PLAYER_CONNECTING = 'vCore:playerConnecting'
vCore.Events.PLAYER_LOADED = 'vCore:playerLoaded'
vCore.Events.PLAYER_DISCONNECTED = 'vCore:playerDisconnected'

-- Character
vCore.Events.CHARACTER_SELECTED = 'vCore:characterSelected'
vCore.Events.CHARACTER_CREATED = 'vCore:characterCreated'
vCore.Events.CHARACTER_DELETED = 'vCore:characterDeleted'

-- Update
vCore.Events.PLAYER_DATA_UPDATED = 'vCore:playerDataUpdated'
vCore.Events.PLAYER_SAVED = 'vCore:playerSaved'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS ÉCONOMIE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.MONEY_ADDED = 'vCore:moneyAdded'
vCore.Events.MONEY_REMOVED = 'vCore:moneyRemoved'
vCore.Events.MONEY_SET = 'vCore:moneySet'
vCore.Events.MONEY_UPDATED = 'vCore:moneyUpdated'

-- Transactions
vCore.Events.TRANSACTION_COMPLETED = 'vCore:transactionCompleted'
vCore.Events.TRANSACTION_FAILED = 'vCore:transactionFailed'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS JOB
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.JOB_CHANGED = 'vCore:jobChanged'
vCore.Events.JOB_DUTY_CHANGED = 'vCore:jobDutyChanged'
vCore.Events.JOB_SALARY_PAID = 'vCore:jobSalaryPaid'
vCore.Events.JOB_ACTION = 'vCore:jobAction'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS GANG
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.GANG_CHANGED = 'vCore:gangChanged'
vCore.Events.GANG_MEMBER_JOINED = 'vCore:gangMemberJoined'
vCore.Events.GANG_MEMBER_LEFT = 'vCore:gangMemberLeft'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS INVENTORY
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.ITEM_ADDED = 'vCore:itemAdded'
vCore.Events.ITEM_REMOVED = 'vCore:itemRemoved'
vCore.Events.ITEM_USED = 'vCore:itemUsed'
vCore.Events.ITEM_DROPPED = 'vCore:itemDropped'
vCore.Events.ITEM_PICKED_UP = 'vCore:itemPickedUp'
vCore.Events.INVENTORY_UPDATED = 'vCore:inventoryUpdated'
vCore.Events.INVENTORY_FULL = 'vCore:inventoryFull'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS VEHICLE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.VEHICLE_SPAWNED = 'vCore:vehicleSpawned'
vCore.Events.VEHICLE_DESPAWNED = 'vCore:vehicleDespawned'
vCore.Events.VEHICLE_STORED = 'vCore:vehicleStored'
vCore.Events.VEHICLE_PURCHASED = 'vCore:vehiclePurchased'
vCore.Events.VEHICLE_SOLD = 'vCore:vehicleSold'
vCore.Events.VEHICLE_DAMAGE_UPDATED = 'vCore:vehicleDamageUpdated'
vCore.Events.VEHICLE_KEYS_GIVEN = 'vCore:vehicleKeysGiven'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS STATUS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.STATUS_UPDATED = 'vCore:statusUpdated'
vCore.Events.STATUS_CRITICAL = 'vCore:statusCritical'
vCore.Events.STATUS_EFFECT_APPLIED = 'vCore:statusEffectApplied'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.ADMIN_ACTION = 'vCore:adminAction'
vCore.Events.PLAYER_KICKED = 'vCore:playerKicked'
vCore.Events.PLAYER_BANNED = 'vCore:playerBanned'
vCore.Events.PLAYER_WARNED = 'vCore:playerWarned'
vCore.Events.TELEPORT_REQUESTED = 'vCore:teleportRequested'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS LOGS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.LOG_CREATED = 'vCore:logCreated'
vCore.Events.LOG_SECURITY = 'vCore:logSecurity'
vCore.Events.LOG_ECONOMY = 'vCore:logEconomy'
vCore.Events.LOG_ADMIN = 'vCore:logAdmin'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS UI
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.UI_SHOW_MENU = 'vCore:ui:showMenu'
vCore.Events.UI_HIDE_MENU = 'vCore:ui:hideMenu'
vCore.Events.UI_SHOW_NUI = 'vCore:ui:showNUI'
vCore.Events.UI_HIDE_NUI = 'vCore:ui:hideNUI'
vCore.Events.UI_NOTIFY = 'vCore:ui:notify'
vCore.Events.UI_HUD_UPDATE = 'vCore:ui:hudUpdate'
vCore.Events.UI_PROGRESS_START = 'vCore:ui:progressStart'
vCore.Events.UI_PROGRESS_STOP = 'vCore:ui:progressStop'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.CALLBACK_REQUEST = 'vCore:callbackRequest'
vCore.Events.CALLBACK_RESPONSE = 'vCore:callbackResponse'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS CLIENT-SIDE
-- ═══════════════════════════════════════════════════════════════════════════

-- Spawning
vCore.Events.CLIENT_SPAWN = 'vCore:client:spawn'
vCore.Events.CLIENT_RESPAWN = 'vCore:client:respawn'

-- Actions
vCore.Events.CLIENT_TELEPORT = 'vCore:teleport'
vCore.Events.CLIENT_SPAWN_VEHICLE = 'vCore:spawnVehicle'
vCore.Events.CLIENT_DELETE_VEHICLE = 'vCore:deleteVehicle'
vCore.Events.CLIENT_REPAIR_VEHICLE = 'vCore:repairVehicle'

-- RP Actions
vCore.Events.CLIENT_SHOW_ME = 'vCore:showMeAction'
vCore.Events.CLIENT_SHOW_DO = 'vCore:showDoAction'

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS SYSTÈME
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events.SYSTEM_READY = 'vCore:systemReady'
vCore.Events.SYSTEM_STOP = 'vCore:systemStop'
vCore.Events.MODULE_LOADED = 'vCore:moduleLoaded'
vCore.Events.MODULE_ERROR = 'vCore:moduleError'

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Déclenche un événement serveur
---@param eventName string
---@param ... any
function vCore.TriggerServerEvent(eventName, ...)
    if IsDuplicityVersion() then
        vCore.Utils.Error('TriggerServerEvent appelé côté serveur!')
        return
    end
    TriggerServerEvent(eventName, ...)
end

---Déclenche un événement client
---@param source number
---@param eventName string
---@param ... any
function vCore.TriggerClientEvent(source, eventName, ...)
    if not IsDuplicityVersion() then
        vCore.Utils.Error('TriggerClientEvent appelé côté client!')
        return
    end
    TriggerClientEvent(eventName, source, ...)
end

---Déclenche un événement local
---@param eventName string
---@param ... any
function vCore.TriggerEvent(eventName, ...)
    TriggerEvent(eventName, ...)
end

print('^2[vCore:Events]^7 Système d\'événements chargé (' .. vCore.Utils.TableCount(vCore.Events) .. ' événements)')
