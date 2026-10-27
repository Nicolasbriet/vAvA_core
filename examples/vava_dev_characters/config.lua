--[[
    vava_dev_characters/config.lua
    Rôle : configuration du module de test (lue par le client et le serveur).
    Dépendances : aucune
]]

VavaDevCharacters = {
    config = {
        coreVersion = '0.4.0',
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
        -- saisie du joueur → valeur attendue par le core
        sexes = { h = 'm', m = 'm', f = 'f' },
        sexLabels = { m = 'homme', f = 'femme' },
        chatAuthor = 'vAvA',
    },
}
