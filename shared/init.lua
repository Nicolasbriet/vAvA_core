--[[
    shared/init.lua
    Rôle : crée la table interne du core (seule globale de la ressource), sa version et les constantes de protocole.
    Dépendances : aucune (premier fichier chargé).
]]

local resourceName = GetCurrentResourceName()

---@class vAvA
---@field name string
---@field version string        version sémantique, lue depuis le fxmanifest (source unique)
---@field apiVersion integer    version majeure courante de l'API publique
---@field resourceName string
---@field isServer boolean
---@field lib table             utilitaires purs (shared/lib)
---@field config table          config.shared partout, config.server côté serveur uniquement
vAvA = {
    name = 'vAvA',
    version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
    apiVersion = 1,
    resourceName = resourceName,
    isServer = IsDuplicityVersion(),
    lib = {},
    config = {},
}

-- Propriétaire réservé aux enregistrements du core lui-même (migrations, hooks core:*). Aucun module ne peut le prendre.
vAvA.CORE_OWNER = 'core'

-- Borne haute des identifiants de requêtes RPC : tient dans un entier 32 bits signé, quel que soit le runtime en face.
vAvA.RPC_MAX_ID = 0x7FFFFFFF

-- Deux paires d'events suffisent pour tout le RPC : validation et rate limiting restent centralisés en un seul point.
vAvA.EVENTS = {
    RPC_REQUEST = 'vAvA:rpc:request',             -- client → serveur (id 0 = emit sans réponse)
    RPC_RESPONSE = 'vAvA:rpc:response',           -- serveur → client
    CLIENT_REQUEST = 'vAvA:rpc:clientRequest',    -- serveur → client
    CLIENT_RESPONSE = 'vAvA:rpc:clientResponse',  -- client → serveur
    -- Toujours envoyés au seul joueur concerné, jamais en broadcast.
    CHARACTER_LOADED = 'vAvA:character:loaded',      -- son personnage et ses champs visibles
    CHARACTER_FIELDS = 'vAvA:character:fields',      -- lot de champs modifiés (regroupés par tick)
    CHARACTER_UNLOADED = 'vAvA:character:unloaded',
    SPAWN = 'vAvA:character:spawn',                  -- ordre d'apparition (position décidée par le serveur)
}

-- RPC des personnages exposés par le core : intentions du joueur, validées et décidées par le serveur.
vAvA.CHARACTER_RPC = {
    LIST = 'core:characters:list',
    CREATE = 'core:characters:create',
    SELECT = 'core:characters:select',
    UNLOAD = 'core:characters:unload',
    DELETE = 'core:characters:delete',
    SPAWNED = 'core:characters:spawned',
}
