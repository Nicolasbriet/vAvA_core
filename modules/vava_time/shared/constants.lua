--[[
    vava_time/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : clés GlobalState, RPC, hooks,
           liens facultatifs avec les autres modules, bornes.
    Dépendances : aucune
]]

VavaTime = {}

-- État partagé avec tous les joueurs (GlobalState : petites valeurs rares, utiles à tous).
VavaTime.STATE = {
    CLOCK = 'vava_time:clock',          -- { shift, frozen } : décalage (s) et seconde du jour figée (false : l'heure court)
    WEATHER = 'vava_time:weather',      -- { id, from, at, fade, forced, frozen } : ciel, transition depuis `at` (UTC)
    CALENDAR = 'vava_time:calendar',    -- { season, day, year }
}

-- Intentions du client (RPC à schéma strict, débit limité).
VavaTime.RPC = {
    SYNC = 'vava_time:sync',            -- heure UTC du serveur (à l'arrivée, puis toutes les 30 min)
    OPEN = 'vava_time:open',            -- vue de l'outil du Conseil
    CLOCK = 'vava_time:clock',          -- action, valeur : heure du royaume
    WEATHER = 'vava_time:weather',      -- action, ciel, figer : météo
}

-- Hooks déclenchés par le module (serveur, after).
VavaTime.HOOKS = {
    SEASON = 'vava_time:seasonChanged',   -- { season, previous, day, year }
    DAY = 'vava_time:dayChanged',         -- { season, day, year }
    WEATHER = 'vava_time:weatherChanged', -- { weather, previous, forced, frozen, by }
    CLOCK = 'vava_time:clockChanged',     -- { shift, frozen, by }
    FROST_WARNING = 'vava_time:frostWarning', -- { season, day, year, warnHour, hour } : au soir d'une nuit de gel
    FROST = 'vava_time:frost',            -- { season, day, year, warnHour, hour } : le gel tombe (tombée de la nuit)
}

-- Actions du Conseil.
VavaTime.CLOCK_ACTIONS = { 'set', 'shift', 'freeze', 'resume', 'real' }
VavaTime.WEATHER_ACTIONS = { 'impose', 'freeze', 'release' }

-- Bornes (protocole).
VavaTime.DAY_SECONDS = 86400
VavaTime.DAY_MINUTES = 1440
VavaTime.ID_PATTERN = '^[%l_]+$'

-- Liens facultatifs avec le Registre du Conseil (par ses hooks, exports et registres).
VavaTime.ADMIN = {
    RESOURCE = 'vava_admin',
    REGISTRY = 'vava_admin:tools',
    READY = 'vava_admin:toolsReady',
    OPENED = 'vava_admin:toolOpened',
    TOOL = 'vava_time:ciel',
}
