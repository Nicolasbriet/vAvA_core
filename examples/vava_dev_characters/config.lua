--[[
    vava_dev_characters/config.lua
    Rôle : configuration du module de test (lue par le client et le serveur).
    Dépendances : aucune
]]

VavaDevCharacters = {
    config = {
        coreVersion = '0.4.0',

        -- Qui peut s'en servir (le serveur revérifie à chaque appel) : droit vava_admin `permission`, ou ACE `ace`
        -- (console : `add_ace identifier.license:<licence> vava.dev allow`). Rien de plus large : ces outils donnent
        -- des objets, soignent et téléportent. Le mode développement (`set vava_env dev`) est exigé en plus.
        access = { permission = 'staff', ace = 'vava.dev' },
        accessRateLimit = { capacity = 5, refillPerSecond = 1 },

        command = 'perso',
        respawnCommand = 'respawn',
        respawnRateLimit = { capacity = 2, refillPerSecond = 0.1 },
        giveCommand = 'objet',
        giveRateLimit = { capacity = 5, refillPerSecond = 1 },
        maxGiveQuantity = 100,
        needsCommand = 'besoins',
        needsRateLimit = { capacity = 5, refillPerSecond = 1 },
        healthCommand = 'vie',
        downCommand = 'aterre',
        healthRateLimit = { capacity = 5, refillPerSecond = 1 },

        -- Libellés du journal du Registre (vava_admin:log, 32 signes au plus) ; sans Registre, ou pour un joueur qui
        -- n'a que l'ACE, la ligne va à la console du serveur.
        journal = {
            give = 'Outil de test : objet donné',
            health = 'Outil de test : vie fixée',
            down = 'Outil de test : mise à terre',
            needs = 'Outil de test : besoins fixés',
            respawn = 'Outil de test : réapparition',
        },

        -- Réponses du serveur traduites pour le joueur (les autres codes s'affichent tels quels).
        refusals = {
            not_allowed = 'réservé au Conseil (droit staff) ou à l\'ACE vava.dev',
            unknown_rpc = 'outils de développement inactifs sur ce serveur (mode développement absent)',
        },

        -- saisie du joueur → valeur attendue par le core
        sexes = { h = 'm', m = 'm', f = 'f' },
        sexLabels = { m = 'homme', f = 'femme' },
        chatAuthor = 'vAvA',
    },
}
