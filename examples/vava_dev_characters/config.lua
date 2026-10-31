--[[
    vava_dev_characters/config.lua
    Rôle : réglages du module de test que lit le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : version du core, qui peut s'en servir, débits, quantité donnée, libellés du journal. Complète
           la table ouverte par config_client.lua (commandes, refus, sexes, auteur) sans en réécrire une clé (T-132).
    Dépendances : config_client.lua
]]

local config = VavaDevCharacters.config

config.coreVersion = '0.4.0'

-- Qui peut s'en servir (le serveur revérifie à chaque appel) : droit vava_admin `permission`, ou ACE `ace`
-- (console : `add_ace identifier.license:<licence> vava.dev allow`). Rien de plus large : ces outils donnent
-- des objets, soignent et téléportent. Le mode développement (`set vava_env dev`) est exigé en plus.
config.access = { permission = 'staff', ace = 'vava.dev' }
config.accessRateLimit = { capacity = 5, refillPerSecond = 1 }
config.respawnRateLimit = { capacity = 2, refillPerSecond = 0.1 }
config.giveRateLimit = { capacity = 5, refillPerSecond = 1 }
config.maxGiveQuantity = 100
config.needsRateLimit = { capacity = 5, refillPerSecond = 1 }
config.healthRateLimit = { capacity = 5, refillPerSecond = 1 }

-- Libellés du journal du Registre (vava_admin:log, 32 signes au plus) ; sans Registre, ou pour un joueur qui
-- n'a que l'ACE, la ligne va à la console du serveur.
config.journal = {
    give = 'Outil de test : objet donné',
    health = 'Outil de test : vie fixée',
    down = 'Outil de test : mise à terre',
    needs = 'Outil de test : besoins fixés',
    respawn = 'Outil de test : réapparition',
}
