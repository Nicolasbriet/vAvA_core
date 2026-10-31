--[[
    vava_anim_test/config.lua
    Rôle : réglages de l'outil de test des animations que lit le seul serveur (servi au seul serveur, jamais
           téléchargé par les joueurs) : qui peut s'en servir, débit des demandes d'accès. Complète la table ouverte
           par config_client.lua sans en réécrire une clé (T-132).
    Dépendances : config_client.lua
]]

local config = VavaAnimTest.config

-- Qui peut s'en servir : droit vava_admin `permission`, ou ACE `ace` ; le serveur répond à chaque demande
-- d'accès du client, gardée `accessCacheMs` (un droit retiré vaut au plus tard à l'expiration). Le module ne
-- démarre qu'en mode développement (`set vava_env dev`) : sinon aucune commande ne répond.
config.access = { permission = 'staff', ace = 'vava.dev' }
config.accessRateLimit = { capacity = 5, refillPerSecond = 0.5 }
