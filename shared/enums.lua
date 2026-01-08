--[[
    vAvA_core - Énumérations et constantes
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- TYPES D'ARGENT
-- ═══════════════════════════════════════════════════════════════════════════

vCore.MoneyType = {
    CASH = 'cash',
    BANK = 'bank',
    BLACK = 'black_money'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TYPES DE NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.NotifyType = {
    INFO = 'info',
    SUCCESS = 'success',
    WARNING = 'warning',
    ERROR = 'error'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- STATUTS JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

vCore.StatusType = {
    HUNGER = 'hunger',
    THIRST = 'thirst',
    STRESS = 'stress',
    HEALTH = 'health',
    ARMOR = 'armor'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉTATS VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.VehicleState = {
    GARAGED = 'garaged',
    OUT = 'out',
    IMPOUNDED = 'impounded',
    DESTROYED = 'destroyed'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PERMISSIONS ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

vCore.AdminLevel = {
    USER = 0,
    MOD = 1,
    ADMIN = 2,
    SUPERADMIN = 3,
    OWNER = 4
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TYPES DE LOGS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.LogType = {
    INFO = 'info',
    WARNING = 'warning',
    ERROR = 'error',
    DEBUG = 'debug',
    ECONOMY = 'economy',
    INVENTORY = 'inventory',
    JOB = 'job',
    VEHICLE = 'vehicle',
    ADMIN = 'admin',
    SECURITY = 'security'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TYPES D'ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.ItemType = {
    ITEM = 'item',
    WEAPON = 'weapon',
    CONSUMABLE = 'consumable',
    CLOTHING = 'clothing',
    TOOL = 'tool'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Events = {
    -- Player
    PLAYER_LOADED = 'vCore:playerLoaded',
    PLAYER_SPAWNED = 'vCore:playerSpawned',
    PLAYER_DROPPED = 'vCore:playerDropped',
    PLAYER_SAVED = 'vCore:playerSaved',
    
    -- Money
    MONEY_ADDED = 'vCore:moneyAdded',
    MONEY_REMOVED = 'vCore:moneyRemoved',
    MONEY_SET = 'vCore:moneySet',
    
    -- Job
    JOB_CHANGED = 'vCore:jobChanged',
    JOB_DUTY_CHANGED = 'vCore:jobDutyChanged',
    
    -- Inventory
    ITEM_ADDED = 'vCore:itemAdded',
    ITEM_REMOVED = 'vCore:itemRemoved',
    ITEM_USED = 'vCore:itemUsed',
    
    -- Vehicle
    VEHICLE_SPAWNED = 'vCore:vehicleSpawned',
    VEHICLE_STORED = 'vCore:vehicleStored',
    
    -- Status
    STATUS_UPDATED = 'vCore:statusUpdated',
    
    -- Admin
    PLAYER_BANNED = 'vCore:playerBanned',
    PLAYER_KICKED = 'vCore:playerKicked'
}
